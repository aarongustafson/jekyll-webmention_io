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
require_relative "webmentions"

require "json"
require "net/http"
require "uri"
require "openssl"
require "active_support"

module Jekyll
  module WebmentionIO
    class << self
      # define simple getters and setters
      attr_reader :config, :jekyll_config, :cache_files, :cache_folder,
                  :file_prefix, :types, :supported_templates, :js_handler,
                  :policy, :caches, :webmentions
    end

    @logger_prefix = "[jekyll-webmention_io]"

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

    def self.bootstrap(site, caches = nil, policy = nil, webmentions = nil)
      @site = site

      @caches = caches || Caches.new(@site)
      @policy = policy || WebmentionPolicy.new(@site, @caches)
      @webmentions = webmentions || Webmentions.new(@policy)

      @jekyll_config = site.config
      @config = @jekyll_config["webmentions"] || {}

      @js_handler = WebmentionIO::JSHandler.new(site)

      if @config['html_proofer'] == true
        @config['html_proofer_ignore'] = "templates"
      end
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

    def self.log(type, message)
      debug = !!@config.dig("debug")
      if debug || %w(error msg).include?(type)
        type = "info" if type == "msg"
        Jekyll.logger.method(type).call("#{@logger_prefix} #{message}")
      end
    end
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
