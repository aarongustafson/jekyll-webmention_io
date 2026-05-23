# frozen_string_literal: true

require 'fileutils'
require 'jekyll'

module SmokeTest
  # Writes a minimal, self-contained Jekyll site into a scratch directory and
  # hands back a Jekyll configuration for building it. The site is deliberately
  # tiny -- two posts and a layout -- but wired for a full round trip:
  #
  #   * the source post links to the target post (drives leg A: sending), and
  #   * the target post advertises the hub as its webmention endpoint and renders
  #     the {% webmentions %} tag (drives leg B: receiving + rendering).
  #
  # Ports are dynamic, so the source post's link to the target is written as a
  # literal absolute URL -- the queue generator scans raw post content for URLs
  # before Liquid runs, so a `{{ site.url }}` reference wouldn't be found.
  class JekyllSiteBuilder
    SOURCE_PERMALINK = '/source/'
    TARGET_PERMALINK = '/target/'

    attr_reader :root, :site_origin, :source_url, :target_url

    def initialize(root:, site_origin:, hub_endpoint:, hub_api_url:)
      @root = root
      @site_origin = site_origin
      @hub_endpoint = hub_endpoint
      @hub_api_url = hub_api_url
      @source_url = "#{site_origin}#{SOURCE_PERMALINK}"
      @target_url = "#{site_origin}#{TARGET_PERMALINK}"
    end

    def write_sources
      write('_config.yml', config_yml)
      write('_layouts/default.html', layout_html)
      write('_posts/2001-01-01-source-post.md', source_post)
      write('_posts/2001-01-02-target-post.md', target_post)
    end

    def configuration
      Jekyll.configuration(
        'source' => @root,
        'destination' => destination,
        'quiet' => true
      )
    end

    def destination
      File.join(@root, '_site')
    end

    # Where Jekyll writes the rendered target post (permalink => /target/index.html).
    def target_output
      File.join(destination, 'target', 'index.html')
    end

    private

    def write(relative_path, contents)
      path = File.join(@root, relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
    end

    def config_yml
      <<~YAML
        url: "#{@site_origin}"
        webmention_endpoint: "#{@hub_endpoint}"
        webmentions:
          api_url: "#{@hub_api_url}"
          pause_lookups: false
          js: false
      YAML
    end

    def layout_html
      <<~HTML
        <!doctype html>
        <html>
          <head>
            <title>{{ page.title }}</title>
            <link rel="webmention" href="{{ site.webmention_endpoint }}">
          </head>
          <body>
            {{ content }}
          </body>
        </html>
      HTML
    end

    def source_post
      <<~MARKDOWN
        ---
        layout: default
        title: The Source Post
        permalink: #{SOURCE_PERMALINK}
        ---
        This post mentions [the target post](#{@target_url}).
      MARKDOWN
    end

    def target_post
      <<~MARKDOWN
        ---
        layout: default
        title: The Target Post
        permalink: #{TARGET_PERMALINK}
        ---
        Webmentions for this post:

        {% webmentions page.url %}
      MARKDOWN
    end
  end
end
