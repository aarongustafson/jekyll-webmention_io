$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'jekyll'
require 'jekyll-webmention_io'
require 'html-proofer'

def dest_dir
  File.expand_path("../tmp/dest", __dir__)
end

def source_dir
  File.expand_path("fixtures", __dir__)
end

ENV['JEKYLL_LOG_LEVEL'] = 'error'

CONFIG_DEFAULTS = {
  "source"      => source_dir,
  "destination" => dest_dir,
  "gems"        => ["jekyll-webmention_io"],
}.freeze

module SpecHelper
  class MockConfig < Jekyll::WebmentionIO::Config
    def initialize(documents = nil, collections = nil)
      super()

      @documents = documents || []
      @collections = collections || []
    end

    def documents
      @documents
    end

    def collections
      @collections
    end
  end

  class MockCaches
    attr_accessor :incoming_webmentions, :outgoing_webmentions, :bad_uris, :site_lookups

    def initialize
      @incoming_webmentions = MockCache.new
      @outgoing_webmentions = MockCache.new
      @bad_uris = MockCache.new
      @site_lookups = MockCache.new
    end

    class MockCache < Hash
      def write
      end
    end
  end

  class MockWebmentionItem
    attr_accessor :id, :uri, :source, :pubdate, :raw, :author, :type, :title, :content

    def initialize(target:, source:, type:, title: '', content: '', date: '', author: '')
      @id = SecureRandom.uuid
      @uri = target
      @source = source
      @type = type
      @title = title
      @content = content
      @pubdate = date
      @author = author

      @raw = { "id" => @id, "verified_date" => Date.today }
    end

    def to_hash
      the_hash = {
        'id' => @id,
        'uri' => @uri,
        'source' => @source,
        'pubdate' => @pubdate,
        'raw' => @raw,
        'author' => @author,
        'type' => @type,
      }

      the_hash['title'] = @title if @title
      the_hash['content'] = @content || ''

      the_hash
    end
  end

  class MockWebmentions
    attr_accessor :webmentions, :bodies, :last_targets, :last_since_id

    def initialize
      @webmentions = {}
      @bodies = {}
      @last_targets = []
    end

    def add(uri:, source:, type: 'like')
      @webmentions[uri] = MockWebmentionItem.new(target: uri, source: source, type: type)
    end

    def clear
      @webmentions.clear
      @last_targets.clear
      @last_since_id = nil
    end

    def body(uri, body)
      @bodies[uri] = body
    end

    def get_webmentions(targets, since_id)
      @last_targets = targets
      @last_since_id = since_id

      targets.map { |t| @webmentions[t] }.compact
    end

    def get_body_from_uri(uri, redirect_limit = 10, original_uri = false)
    end
  end

  class MockPage
    attr_reader :url, :date, :data, :content

    def initialize(url:, data: {}, date: DateTime.now, content: '')
      @url = url
      @date = date
      @data = data
      @content = content
    end

    def uri
      File.join(Jekyll::WebmentionIO.config.site_url, url)
    end

    def redirect
      File.join(Jekyll::WebmentionIO.config.site_url, data["redirect_from"]) if data.key?("redirect_from")
    end

    def path
      url
    end
  end

  def self.make_page(options = {})
    page = Jekyll::Page.new site, CONFIG_DEFAULTS["source"], "", "page.md"
    page.data = options
    page
  end

  def self.make_post(options = {})
    filename = File.expand_path("_posts/2001-01-01-post.md", CONFIG_DEFAULTS["source"])
    config = { :site => site, :collection => site.collections["posts"] }
    page = Jekyll::Document.new filename, config
    page.merge_data!(options)
    page
  end

  def self.make_site(options = {})
    config = Jekyll.configuration CONFIG_DEFAULTS.merge(options)
    Jekyll::Site.new(config)
  end

  def self.make_context(registers = {}, environments = {})
    Liquid::Context.new(environments, {}, { :site => site, :page => page }.merge(registers))
  end
end
