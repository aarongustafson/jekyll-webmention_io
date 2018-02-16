# frozen_string_literal: false

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
require_relative "webmention_io/version"
require_relative "webmention_io/webmention"

require "json"
require "net/http"
require "uri"
require "openssl"
require "string_inflection"
require "webmention"

module Jekyll
  module WebmentionIO

    @logger_prefix = "[jekyll-webmention_io]"

    @api_url = "https://webmention.io/api"
    @api_endpoint = @api_url
    @api_suffix = ""

    @types = %w(likes links posts replies reposts)

    EXCEPTIONS = [  SocketError, Timeout::Error, Errno::EINVAL,
                    Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError,
                    Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
                    Net::ProtocolError, OpenSSL::SSL::SSLError, ].freeze

    def self.bootstrap
      # @jekyll_config = Jekyll.configuration({ 'quiet' => true })
      @jekyll_config = Jekyll.configuration({})
      @config = @jekyll_config["webmentions"] || {}

      # Set up the cache folder & files
      @cache_folder = @config["cache_folder"] || ".jekyll-cache"
      Dir.mkdir(@cache_folder) unless File.exist?(@cache_folder)
      @file_prefix = ""
      unless @cache_folder.include? "webmention"
        @file_prefix = "webmention_io_"
      end
      @cache_files = {
        "incoming" => "#{@cache_folder}/#{@file_prefix}received.yml",
        "outgoing" => "#{@cache_folder}/#{@file_prefix}outgoing.yml",
        "bad_uris" => "#{@cache_folder}/#{@file_prefix}bad_uris.yml",
      }
      @cache_files.each do |_key, file|
        unless File.exist?(file)
          File.open(file, "w") { |f| YAML.dump({}, f) }
        end
      end
    end

    # Getters
    def self.config
      @config
    end

    def self.jekyll_config
      @jekyll_config
    end

    def self.cache_files
      @cache_files
    end

    def self.cache_folder
      @cache_folder
    end

    def self.file_prefix
      @file_prefix
    end

    def self.types
      @types
    end

    # Setters
    def self.api_path=(path)
      @api_endpoint = "#{@api_url}/#{path}"
    end

    def self.api_suffix=(suffix)
      @api_suffix = suffix
    end

    # Heplers
    def self.get_cache_file_path(key)
      path = false
      if @cache_files.key? key
        path = @cache_files[key]
      end
      return path
    end

    def self.read_cached_webmentions(which)
      unless %w(incoming outgoing).include? which
        return {}
      end

      cache_file = get_cache_file_path which
      cached_webmentions = open(cache_file) { |f| YAML.load(f) }

      cached_webmentions
    end

    def self.cache_webmentions(which, webmentions)
      if %w(incoming outgoing).include? which
        cache_file = get_cache_file_path which
        File.open(cache_file, "w") { |f| YAML.dump(webmentions, f) }

        Jekyll::WebmentionIO.log "info", "#{which.capitalize} webmentions have been cached."
      end
    end

    # API helpers
    # def uri_params_for(api_params)
    #  api_params.keys.sort.map do |k|
    #    "#{CGI::escape(k)}=#{CGI::escape(api_params[k])}"
    #  end.join('&')
    # end

    def self.get_response(api_params)
      api_params << @api_suffix
      source = get_uri_source(@api_endpoint + "?#{api_params}")
      if source
        JSON.parse(source)
      else
        ""
      end
    end

    # allowed throttles: last_week, last_month, last_year, older
    # allowed values:  daily, weekly, monthly, yearly, every X days|weeks|months|years
    def self.post_should_be_throttled?(post, item_date, last_webmention_date)
      throttles = @config.dig("throttle_lookups")
      if throttles && item_date && last_webmention_date
        age = get_timeframe_from_date(item_date)
        throttle = throttles.dig(age)
        if throttle && Date.parse(last_webmention_date) >= get_date_from_string(throttle)
          log "info", "Throttling #{post.data["title"]} (Only checking it #{throttle})"
          return true
        end
      end
      return false
    end

    def self.get_timeframe_from_date(time)
      date = time.to_date
      timeframes = {
        "last_week"  => "weekly",
        "last_month" => "monthly",
        "last_year"  => "yearly",
      }
      timeframe = nil
      timeframes.each do |key, value|
        if date.to_date > get_date_from_string(value)
          timeframe = key
          break
        end
      end
      unless timeframe
        timeframe = "older"
      end
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
                 "every 1 " + text.sub("ly", "")
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
      # log 'info', "Looking for webmention endpoint at #{uri}"
      begin
        endpoint = Webmention::Client.supports_webmention?(uri)
        unless endpoint
          log "info", "Could not find a webmention endpoint at #{uri}"
        end
      rescue => e
        log "info", "Endpoint lookup failed for #{uri}: #{e.message}"
        endpoint = false
      end
      endpoint
    end

    def self.webmention(source, target, endpoint)
      log "info", "Sending webmention of #{target} in #{source}"
      # return `curl -s -i -d \"source=#{source}&target=#{target}\" -o /dev/null #{endpoint}`
      response = Webmention::Client.send_mention(endpoint, source, target, true)
      status = response.dig("parsed_response", "data", "status").to_s
      if status == "200"
        log "info", "Webmention successful!"
        return response.response.body
      else
        log "info", "Webmention failed, but will remain queued for next time"
        false
      end
    end

    def self.get_template_contents(template)
      template_file = if Jekyll::WebmentionIO.config.dig("templates", template)
                        # Jekyll::WebmentionIO.log 'info', "Using custom #{template} template"
                        Jekyll::WebmentionIO.config["templates"][template]
                      else
                        File.expand_path("templates/#{template}.html", __dir__)
                      end
      # Jekyll::WebmentionIO.log 'info', "Template file: #{template_file}"
      handler = File.open(template_file, "rb")
      handler.read
    end

    # Connections
    def self.uri_ok?(uri)
      uri = URI.parse(URI.encode(uri))
      now = Time.now.to_s
      bad_uris = open(@cache_files["bad_uris"]) { |f| YAML.load(f) }
      if bad_uris.key? uri.host
        last_checked = DateTime.parse(bad_uris[uri.host])
        cache_bad_uris_for = @config["cache_bad_uris_for"] || 1 # in days
        recheck_at = last_checked.next_day(cache_bad_uris_for).to_s
        if recheck_at > now
          return false
        end
      end
      return true
    end

    # Cache bad URLs for a bit
    def self.uri_is_not_ok(uri)
      # Never cache webmention.io in here
      if uri.host == "webmention.io"
        return
      end
      cache_file = @cache_files["bad_uris"]
      bad_uris = open(cache_file) { |f| YAML.load(f) }
      bad_uris[uri.host] = Time.now.to_s
      File.open(cache_file, "w") { |f| YAML.dump(bad_uris, f) }
    end

    def self.get_uri_source(uri, redirect_limit = 10, original_uri = false)
      original_uri ||= uri
      unless uri_ok?(uri)
        return false
      end
      if redirect_limit.positive?
        uri = URI.parse(URI.encode(uri))
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10
        if uri.scheme == "https"
          http.use_ssl = true
          http.ciphers = "ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:-LOW"
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        begin
          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)
        rescue *EXCEPTIONS => e
          log "warn", "Got an error checking #{original_uri}: #{e}"
          uri_is_not_ok(uri)
          return false
        end
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
        if original_uri
          log "warn", "too many redirects for #{original_uri}"
        end
        uri_is_not_ok(uri)
        return false
      end
    end

    def self.log(type, message)
      Jekyll.logger.method(type).call("#{@logger_prefix} #{message}")
    end

  end
end

# Load all the bits
Dir[File.expand_path("commands/*.rb", __dir__)].each do |file|
  require file
end
Dir[File.expand_path("generators/*.rb", __dir__)].each do |file|
  require file
end
require "#{__dir__}/tags/_.rb"
Dir[File.expand_path("tags/*.rb", __dir__)].each do |file|
  require file unless file.include? "_.rb"
end
