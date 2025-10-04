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
require_relative "templates"

module Jekyll
  module WebmentionIO
    class << self
      # define simple getters and setters
      attr_reader :types, :config, :cache_files, :js_handler,
                  :policy, :caches, :webmentions, :templates
    end

    @types = %w(bookmarks likes links posts replies reposts rsvps).freeze

    @logger_prefix = "[jekyll-webmention_io]"

    def self.bootstrap(site, config = nil, caches = nil, policy = nil, webmentions = nil, templates = nil)
      @site = site

      @config = config || Config.new(@site)
      @caches = caches || Caches.new(@config)
      @policy = policy || WebmentionPolicy.new(@config, @caches)
      @webmentions = webmentions || Webmentions.new(@policy)
      @templates = templates || Templates.new(site)

      @js_handler = WebmentionIO::JSHandler.new()
    end

    def self.log(type, message)
      if @config.debug || %w(error msg).include?(type)
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
