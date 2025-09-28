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
require_relative "config"

require "json"
require "net/http"
require "uri"
require "openssl"
require "active_support"

module Jekyll
  module WebmentionIO
    class << self
      # define simple getters and setters
      attr_reader :config, :cache_files, :cache_folder,
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

    def self.bootstrap(site, config = nil, caches = nil, policy = nil, webmentions = nil)
      @site = site

      @config = config || Config.new(@site)
      @caches = caches || Caches.new(@config)
      @policy = policy || WebmentionPolicy.new(@config, @caches)
      @webmentions = webmentions || Webmentions.new(@policy)

      @js_handler = WebmentionIO::JSHandler.new()
    end

    def self.gather_documents(site)
      documents = site.posts.docs.clone

      if @config.pages == true
        log "info", "Including site pages."
        documents.concat site.pages.clone
      end

      if !@config.collections.empty?
        log "info", "Adding collections."

        site.collections.each do |name, collection|
          # skip _posts
          next if name == "posts"

          if @config.collections.include?(name)
            documents.concat collection.docs.clone
          end
        end
      end

      return documents
    end

    def self.template_file(template)
      @template_file_cache[template] ||= begin
        configured_template = @config.templates[template]

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
      setting = @config.html_proofer_ignore
      proofer = if setting == Config::HtmlProofer.ALL || setting == Config::HtmlProofer.TEMPLATES
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
