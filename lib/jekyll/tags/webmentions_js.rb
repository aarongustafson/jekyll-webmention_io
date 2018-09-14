# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  JS stuff
#

module Jekyll
  module WebmentionIO
    class WebmentionJSTag < Liquid::Tag
      def render(_context)
        WebmentionIO.js_handler.render
      end
    end
  end
end

Liquid::Template.register_tag("webmentions_js", Jekyll::WebmentionIO::WebmentionJSTag)
