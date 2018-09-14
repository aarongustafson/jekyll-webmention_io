# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#

module Jekyll
  module WebmentionIO
    class JSHandler
      attr_reader :destination, :resource_url

      DEFAULTS = {
        "destination" => "js",
        "source"      => true,
        "deploy"      => true,
        "uglify"      => true,
      }.freeze

      def initialize(site)
        js_config = site.config.dig("webmentions", "js")

        @disabled = js_config == false

        js_config = {} unless js_config.is_a?(Hash)
        js_config = DEFAULTS.merge(js_config)

        @deploy, @uglify, @source, @destination = js_config.values_at("deploy", "uglify", "source", "destination")
        @resource_url = File.join(
          "", site.config["baseurl"], @destination, "JekyllWebmentionIO.js"
        )
      end

      def disabled?
        @disabled == true
      end

      def deploy?
        @deploy != false
      end

      def uglify?
        @uglify != false
      end

      def source?
        @source != false
      end

      def render
        if disabled?
          Jekyll::WebmentionIO.log "info",
            "JavaScript output is disabled, so the {% webmentions_js %} tag is being skipped"
          return ""
        end

        js_file = deploy? ? "<script src=\"#{resource_url}\" async></script>" : ""

        Jekyll::WebmentionIO.log "info", "Gathering templates for JavaScript."
        "#{js_file}\n#{Jekyll::WebmentionIO.html_templates}"
      end
    end
  end
end
