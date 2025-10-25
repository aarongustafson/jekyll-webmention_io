# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#

module Jekyll
  module WebmentionIO
    class JSHandler
      def render
        if WebmentionIO.config.js.disabled?
          WebmentionIO.log 'info',
                           'JavaScript output is disabled, so the {% webmentions_js %} tag is being skipped'
          return ''
        end

        js_file = WebmentionIO.config.js.deploy? ? "<script src=\"#{WebmentionIO.config.js.resource_url}\" async></script>" : ''

        WebmentionIO.log 'info', 'Gathering templates for JavaScript.'

        "#{js_file}\n#{WebmentionIO.templates.html_templates}"
      end
    end
  end
end
