# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
require_relative "webmention_io/version"
require_relative "webmention_io/webmention_item"
require_relative "webmention_io/js_handler"

require "json"
require "net/http"
require "uri"
require "openssl"
require "active_support"
require "indieweb/endpoints"
require "webmention"

module Jekyll
  module WebmentionIO
    module UriState
      UNSUPPORTED = "unsupported"
      ERROR = "error"
      FAILURE = "failure"
      SUCCESS = "success"
    end

    module UriPolicy
      BAN = "ban"
      IGNORE = "ignore"
      RETRY = "retry"
    end

    class << self
      # define simple getters and setters
      attr_reader :config, :jekyll_config, :cache_files, :cache_folder,
                  :file_prefix, :types, :supported_templates, :js_handler,
                  :uri_whitelist, :uri_blacklist
      attr_writer :api_suffix
    end

    @logger_prefix = "[jekyll-webmention_io]"

    @api_url = "https://webmention.io/api"
    @api_endpoint = @api_url
    @api_suffix = ""

    @types = %w(bookmarks likes links posts replies reposts rsvps).freeze
    @supported_templates = (@types + %w(count webmentions)).freeze

    @template_file_cache = {}
    @template_content_cache = {}
    @webmention_data_cache = {}

    EXCEPTIONS = [
      SocketError, Timeout::Error,
      Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
      OpenSSL::SSL::SSLError,
    ].freeze

    def self.bootstrap(site)
      @site = site
      @jekyll_config = site.config
      @config = @jekyll_config["webmentions"] || {}

      # Set up the cache folder & files
      @cache_folder = site.in_source_dir(@config["cache_folder"] || ".jekyll-cache")
      Dir.mkdir(@cache_folder) unless File.exist?(@cache_folder)
      @file_prefix = ""
      @file_prefix = "webmention_io_" unless @cache_folder.include? "webmention"
      @cache_files = {
        "incoming" => cache_file("received.yml"),
        "outgoing" => cache_file("outgoing.yml"),
        "bad_uris" => cache_file("bad_uris.yml"),
        "lookups"  => cache_file("lookups.yml")
      }
      @cache_files.each_value do |file|
        dump_yaml(file) unless File.exist?(file)
      end

      @js_handler = WebmentionIO::JSHandler.new(site)

      @uri_whitelist = @config
        .fetch("bad_uri_policy", {})
        .fetch("whitelist", [])
        .clone
        .insert(-1, "^https?://webmention.io/")
        .map { |expr| Regexp.new(expr) }

      @uri_blacklist = @config
        .fetch("bad_uri_policy", {})
        .fetch("blacklist", [])
        .map { |expr| Regexp.new(expr) }

      # Backward compatibility config for html_proofer setting

      if @config['html_proofer'] == true
        @config['html_proofer_ignore'] = "templates"
      end
    end

    # Setter
    def self.api_path=(path)
      @api_endpoint = "#{@api_url}/#{path}"
    end

    # Helpers
    def self.cache_file(filename)
      Jekyll.sanitized_path(@cache_folder, "#{@file_prefix}#{filename}")
    end

    def self.max_attempts()
      @config.dig("max_attempts")
    end

    def self.get_cache_file_path(key)
      @cache_files[key] || false
    end

    def self.read_cached_webmentions(which)
      return {} unless %w(incoming outgoing).include?(which)

      cache_file = get_cache_file_path which
      load_yaml(cache_file)
    end

    def self.cache_webmentions(which, webmentions)
      if %w(incoming outgoing).include? which
        cache_file = get_cache_file_path which
        dump_yaml(cache_file, webmentions)

        log "msg", "#{which.capitalize} webmentions have been cached."
      end
    end

    def self.gather_documents(site)
      documents = site.posts.docs.clone

      if @config.dig("pages") == true
        log "info", "Including site pages."
        documents.concat site.pages.clone
      end

      collections = @config.dig("collections")
      if collections
        log "info", "Adding collections."
        site.collections.each do |name, collection|
          # skip _posts
          next if name == "posts"

          unless collections.is_a?(Array) && !collections.include?(name)
            documents.concat collection.docs.clone
          end
        end
      end

      return documents
    end

    def self.get_response(api_params)
      api_params << @api_suffix
      url = URI::Parser.new.escape("#{@api_endpoint}?#{api_params}")
      log "info", "Sending request to #{url}."
      source = get_uri_source(url)
      if source
        JSON.parse(source)
      else
        {}
      end
    end

    def self.read_lookup_dates
      cache_file = get_cache_file_path "lookups"
      load_yaml(cache_file)
    end

    def self.cache_lookup_dates(lookups)
      cache_file = get_cache_file_path "lookups"
      dump_yaml(cache_file, lookups)

      log "msg", "Lookups have been cached."
    end

    # allowed throttles: last_week, last_month, last_year, older
    # allowed values:  daily, weekly, monthly, yearly, every X days|weeks|months|years
    def self.post_should_be_throttled?(post, item_date, last_lookup)
      throttles = @config.dig("throttle_lookups")
      if throttles && item_date && last_lookup
        age = get_timeframe_from_date(item_date)
        throttle = throttles.dig(age)
        if throttle && last_lookup >= get_date_from_string(throttle)
          log "info", "Throttling #{post.data["title"]} (Only checking it #{throttle})"
          return true
        end
      end
      return false
    end

    TIMEFRAMES = {
      "last_week"  => "weekly",
      "last_month" => "monthly",
      "last_year"  => "yearly",
    }.freeze

    def self.get_timeframe_from_date(time)
      date = time.to_date
      timeframe = nil
      TIMEFRAMES.each do |key, value|
        if date.to_date > get_date_from_string(value)
          timeframe = key
          break
        end
      end
      timeframe ||= "older"
      return timeframe
    end

    # supported: daily, weekly, monthly, yearly, every X days|weeks|months|years
    def self.get_date_from_string(text)
      today = Date.today
      pattern = /every\s(?:(\d+)\s)?(day|week|month|year)s?/
      matches = text.match(pattern)
      unless matches
        text = if text == "daily"
                 "every 1 day"
               else
                 "every 1 #{text.sub("ly", "")}"
               end
        matches = text.match(pattern)
      end
      n = matches[1] ? matches[1].to_i : 1
      unit = matches[2]
      # weeks aren't natively supported in Ruby
      if unit == "week"
        n *= 7
        unit = "day"
      end
      # dynamic method call
      return today.send "prev_#{unit}", n
    end

    def self.get_webmention_endpoint(uri)
      # log "info", "Looking for webmention endpoint at #{uri}"
      begin
        endpoint = IndieWeb::Endpoints.get(uri)[:webmention]
        unless endpoint
          log("info", "Could not find a webmention endpoint at #{uri}")
          update_uri_cache(uri, UriState::UNSUPPORTED)
        end
      rescue StandardError => e
        log "info", "Endpoint lookup failed for #{uri}: #{e.message}"
        update_uri_cache(uri, UriState::FAILURE)
        endpoint = false
      end
      endpoint
    end

    def self.webmention(source, target)
      log "info", "Sending webmention of #{target} in #{source}"
      # return `curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint}`
      response = Webmention.send_webmention(source, target)

      case response.code
      when 200, 201, 202
        log "info", "Webmention successful!"
        update_uri_cache(target, UriState::SUCCESS)
        response.body
      else
        log "info", response.inspect
        log "info", "Webmention failed, but will remain queued for next time"

        if response.body
          begin
            body = JSON.parse(response.body)

            if body.key? "error"
              log "msg", "Endpoint returned error: #{body['error']}"
            end
          rescue
          end
        end

        update_uri_cache(target, UriState::ERROR)
        false
      end
    end

    def self.template_file(template)
      @template_file_cache[template] ||= begin
        configured_template = @config.dig("templates", template)
        if configured_template
          log "info", "Using custom #{template} template from site source"
          @site.in_source_dir configured_template
        else
          File.expand_path("templates/#{template}.html", __dir__)
        end
      end
    end

    def self.get_template_contents(template)
      template_file = template_file(template)
      @template_content_cache[template_file] ||= begin
        log "info", "Template file: #{template_file}"
        File.read(template_file)
      end
    end

    def self.html_templates
      setting = @config['html_proofer_ignore']
      proofer = if setting == "all" || setting == "templates"
                  ' data-proofer-ignore'
                else
                  ''
                end
      @html_templates ||= begin
        templates = +"" # unfrozen String
        supported_templates.each do |template|
          templates << "<template style=\"display:none\" id=\"webmention-#{template}\"#{proofer}>"
          templates << get_template_contents(template)
          templates << "</template>"
        end
        templates
      end
    end

    # Connections
    def self.get_uri_source(uri, redirect_limit = 10, original_uri = false)
      original_uri ||= uri
      return false unless uri_ok?(uri)

      if redirect_limit.positive?
        response = get_http_response(uri)
        case response
        when Net::HTTPSuccess then
          return response.body.force_encoding("UTF-8")
        when Net::HTTPRedirection then
          redirect_to = URI::Parser.new.parse(response["location"])
          redirect_to = redirect_to.relative? ? "#{original_uri.scheme}://#{original_uri.host}" + redirect_to.to_s : redirect_to.to_s
          return get_uri_source(redirect_to, redirect_limit - 1, original_uri)
        else
          update_uri_cache(uri, UriState::FAILURE)
          return false
        end
      else
        log("warn", "too many redirects for #{original_uri}") if original_uri
        update_uri_cache(uri, UriState::FAILURE)
        return false
      end
    end

    def self.log(type, message)
      debug = !!@config.dig("debug")
      if debug || %w(error msg).include?(type)
        type = "info" if type == "msg"
        Jekyll.logger.method(type).call("#{@logger_prefix} #{message}")
      end
    end

    # Utility Method
    # Caches given +data+ to memory and then proceeds to write +data+
    # as YAML string into +file+ path.
    #
    # Returns nothing.
    def self.dump_yaml(file, data = {})
      @webmention_data_cache[file] = data
      File.open(file, "wb") { |f| f.puts YAML.dump(data) }
    end

    # Utility Method
    # Attempts to first load data cached in memory and then proceeds to
    # safely parse given YAML +file+ path and return data.
    #
    # Returns empty hash if parsing fails to return data
    def self.load_yaml(file)
      @webmention_data_cache[file] || SafeYAML.load_file(file) || {}
    end

    # Private Methods

    def self.get_http_response(uri)
      uri = URI::Parser.new.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10

      if uri.scheme == "https"
        http.use_ssl = true
        http.ciphers = "ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:-LOW"
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      begin
        request  = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        return response
      rescue *EXCEPTIONS => e
        log "warn", "Got an error checking #{uri}: #{e}"
        update_uri_cache(uri, UriState::FAILURE)
        return false
      end
    end

    # Given the provided state value (see UriState), retrieve the policy
    # entry.  If no entry exists, return a new default entry that
    # indicates unlimited retries.
    def self.get_bad_uri_policy_entry(state)
      settings = @config.fetch("bad_uri_policy", {})

      default_policy = { "policy" => UriPolicy::RETRY }
      policy_entry = nil

      # Retrieve the policy entry, the default entry, or the canned default
      policy_entry = settings.fetch(state) {
        settings.fetch("default", default_policy)
      }

      # Convert shorthand entry to full policy record
      if policy_entry.instance_of? String
        policy_entry = { "policy" => policy_entry }
      end

      if policy_entry["policy"] == UriPolicy::RETRY and ! policy_entry.key? "retry_delay"
        # If this is a retry policy and no delay is set, set up the default
        # delay policy.  This inherits from the legacy cache_bad_uris_for
        # setting to enable backward compatibility with older configurations.
        #
        # We do this here to make the rule enforcement logic a little tidier.

        policy_entry["retry_delay"] = [ @config.fetch("cache_bad_uris_for", 1) * 24 ]
      end

      return policy_entry
    end

    # Retrieve the bad_uris cache entry for the given URI.  This method
    # takes the cache and a URI instance (i.e. parsing must already be done).
    #
    # If the URI has no entry in the cache, returns nil and *not* a default
    # entry.
    def self.get_bad_uri_cache_entry(bad_uris, uri)
      return nil if ! bad_uris.key? uri.host

      entry = bad_uris[uri.host].clone

      if entry.instance_of? String
        # Older version of the bad URL cache, convert to new format with some
        # "sensible" defaults.

        entry = {
          "state" => UriState::UNSUPPORTED,
          "last_checked" => DateTime.parse(entry).to_time,
          "attempts" => 1
        }
      else
        # Otherwise, parse the check time into a real Time object before
        # returning the entry.
        #
        # We convert to a Time object so we can do arithmetic on it later.

        entry["last_checked"] = DateTime.parse(entry["last_checked"]).to_time
      end

      return entry
    end

    # Update the URI cache for this entry.
    #
    # If the state is UriState.SUCCESS or the URI is whitelisted or
    # blacklisted, we delete any existing entries since no policy will
    # apply.  This ensures we reset the policy state when a webmention
    # succeeds.
    #
    # Otherwise, we either create or update an entry for the URI, recording
    # the state and the current attempt counter.
    def self.update_uri_cache(uri, state)
      uri = URI::Parser.new.parse(uri.to_s)
      uri_str = uri.to_s

      cache_file = @cache_files["bad_uris"]
      bad_uris = load_yaml(cache_file)

      if state == UriState::SUCCESS or
          @uri_whitelist.any? { |expr| expr.match uri_str } or
          @uri_blacklist.any? { |expr| expr.match uri_str }

        return if bad_uris.delete(uri.host).nil?
      else
        old_entry = get_bad_uri_cache_entry(bad_uris, uri) || {}

        bad_uris[uri.host] = {
          "state" => state,
          "attempts" => old_entry.fetch("attempts", 0) + 1,
          "last_checked" => Time.now.to_s
        }
      end

      dump_yaml(cache_file, bad_uris)
    end

    # Check if we should attempt to send a webmention to the given URI based
    # on the error handling policy and the last attempt.
    def self.uri_ok?(uri)
      uri = URI::Parser.new.parse(uri.to_s)
      now = Time.now.to_s
      uri_str = uri.to_s

      # If the URI is whitelisted, it's always ok!
      return true if @uri_whitelist.any? { |expr| expr.match uri_str }

      # If the URI is blacklisted, it's never ok!
      return false if @uri_blacklist.any? { |expr| expr.match uri_str }

      bad_uris = load_yaml(@cache_files["bad_uris"])
      entry = get_bad_uri_cache_entry(bad_uris, uri)

      # If the entry isn't in our cache yet, then it's ok.
      return true if entry.nil?

      # Okay, the last time we tried to send a webmention to this URI it
      # failed, so depending on what happened and the policy, we need to
      # decide what to do.
      #
      # First pull the retry policy given the type of the last error for the URI
      policy_entry = get_bad_uri_policy_entry(entry["state"])
      policy = policy_entry["policy"]

      if policy == UriPolicy::BAN
        return false
      elsif policy == UriPolicy::IGNORE
        return true
      elsif policy == UriPolicy::RETRY
        now = Time.now

        attempts = entry["attempts"]
        max_attempts = policy_entry["max_attempts"]

        if ! max_attempts.nil? and attempts >= max_attempts
          # If there's a retry limit and we've hit it, URI is not ok.
          log "msg", "Skipping #{uri}, attempted #{attempts} times and max is #{max_attempts}"

          return false
        end

        retry_delay = policy_entry["retry_delay"]

        # Sneaky trick.  By clamping to the array length, the last entry in
        # the retry_delay list is used for all remaining retries.
        delay = retry_delay[(attempts - 1).clamp(0, retry_delay.length - 1)]

        recheck_at = (entry["last_checked"] + delay * 3600)

        if recheck_at.to_r > now.to_r
          log "msg", "Skipping #{uri}, next attempt will happen after #{recheck_at}"

          return false
        end
      else
        log "error", "Invalid bad URI policy type: #{policy}"
      end

      return true
    end

    private_class_method :get_http_response,
                         :get_bad_uri_policy_entry,
                         :get_bad_uri_cache_entry,
                         :update_uri_cache
  end
end

# Load all the bits
def require_all(group)
  Dir[File.expand_path("#{group}/*.rb", __dir__)].each do |file|
    require file
  end
end

require_all "commands"
require_all "generators"

require_relative "tags/webmention"
require_relative "tags/webmention_type"
require_all "tags"
