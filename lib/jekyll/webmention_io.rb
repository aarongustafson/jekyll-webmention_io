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
require_relative "webmention_policy"

require "json"
require "net/http"
require "uri"
require "openssl"
require "active_support"
require "indieweb/endpoints"
require "webmention"

module Jekyll
  module WebmentionIO
    class << self
      # define simple getters and setters
      attr_reader :config, :jekyll_config, :cache_files, :cache_folder,
                  :file_prefix, :types, :supported_templates, :js_handler,
                  :policy, :caches
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

    def self.bootstrap(site, caches = nil, policy = nil)
      @site = site

      @caches = caches || Caches.new(@site)
      @policy = policy || WebmentionPolicy.new(@site, @caches)

      @jekyll_config = site.config
      @config = @jekyll_config["webmentions"] || {}

      @js_handler = WebmentionIO::JSHandler.new(site)

      if @config['html_proofer'] == true
        @config['html_proofer_ignore'] = "templates"
      end
    end

    # Setter
    def self.api_path=(path)
      @api_endpoint = "#{@api_url}/#{path}"
    end

    def self.max_attempts()
      @config.dig("max_attempts")
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

    private_class_method :get_http_response 
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
