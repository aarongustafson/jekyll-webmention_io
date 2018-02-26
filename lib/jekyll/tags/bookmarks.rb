# frozen_string_literal: false

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_bookmarks post.url %}
#
module Jekyll
  module WebmentionIO
    class WebmentionBookmarksTag < Jekyll::WebmentionIO::WebmentionTag
      def initialize(tag_name, text, tokens)
        super
        @text = text
        self.template = "bookmarks"
      end

      def set_data(data, _types)
        webmentions = extract_type "bookmarks", data
        @data = { "webmentions" => webmentions.values }
      end
    end
  end
end

Liquid::Template.register_tag("webmention_bookmarks", Jekyll::WebmentionIO::WebmentionBookmarksTag)
