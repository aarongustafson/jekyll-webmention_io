$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'jekyll'
require 'jekyll-webmention_io'
require 'html-proofer'
require 'json'

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
