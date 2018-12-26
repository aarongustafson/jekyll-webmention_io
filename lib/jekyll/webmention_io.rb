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
require "string_inflection"
require "webmention"

module Jekyll
  module WebmentionIO
    class << self
      # define simple getters and setters
      attr_reader :config, :jekyll_config, :cache_files, :cache_folder,
                  :file_prefix, :types, :supported_templates, :js_handler
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
    end

    # Setter
    def self.api_path=(path)
      @api_endpoint = "#{@api_url}/#{path}"
    end

    # Helpers
    def self.cache_file(filename)
      Jekyll.sanitized_path(@cache_folder, "#{@file_prefix}#{filename}")
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
      url = "#{@api_endpoint}?#{api_params}"
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
        endpoint = Webmention::Client.supports_webmention?(uri)
        unless endpoint
          log("info", "Could not find a webmention endpoint at #{uri}")
          uri_is_not_ok(uri)
        end
      rescue StandardError => e
        log "info", "Endpoint lookup failed for #{uri}: #{e.message}"
        uri_is_not_ok(uri)
        endpoint = false
      end
      endpoint
    end

    def self.webmention(source, target, endpoint)
      log "info", "Sending webmention of #{target} in #{source}"
      # return `curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint}`
      mention = Webmention::Client.send_mention(endpoint, source, target, true)
      case mention.response
      when Net::HTTPOK, Net::HTTPCreated, Net::HTTPAccepted
        log "info", "Webmention successful!"
        mention.response.body
      else
        log "info", mention.inspect
        log "info", "Webmention failed, but will remain queued for next time"
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
      proofer = if @config['html_proofer'] == true
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
          redirect_to = URI.parse(URI.encode(response["location"]))
          redirect_to = redirect_to.relative? ? "#{uri.scheme}://#{uri.host}" + redirect_to.to_s : redirect_to.to_s
          return get_uri_source(redirect_to, redirect_limit - 1, original_uri)
        else
          uri_is_not_ok(uri)
          return false
        end
      else
        log("warn", "too many redirects for #{original_uri}") if original_uri
        uri_is_not_ok(uri)
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
      uri  = URI.parse(URI.encode(uri))
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
        uri_is_not_ok(uri)
        return false
      end
    end

    # Cache bad URLs for a bit
    def self.uri_is_not_ok(uri)
      uri = URI.parse(URI.encode(uri))
      # Never cache webmention.io in here
      return if uri.host == "webmention.io"

      cache_file = @cache_files["bad_uris"]
      bad_uris = load_yaml(cache_file)
      bad_uris[uri.host] = Time.now.to_s
      dump_yaml(cache_file, bad_uris)
    end

    def self.uri_ok?(uri)
      uri = URI.parse(URI.encode(uri))
      now = Time.now.to_s
      bad_uris = load_yaml(@cache_files["bad_uris"])
      if bad_uris.key? uri.host
        last_checked = DateTime.parse(bad_uris[uri.host])
        cache_bad_uris_for = @config["cache_bad_uris_for"] || 1 # in days
        recheck_at = last_checked.next_day(cache_bad_uris_for).to_s
        return false if recheck_at > now
      end
      return true
    end

    private_class_method :get_http_response, :uri_is_not_ok
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
