#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_rsvps post.url %}
#
module Jekyll
  module WebmentionIO
    class WebmentionRsvpsTag < Jekyll::WebmentionIO::WebmentionTag
      def initialize(tagName, text, tokens)
        super
        @text = text
        set_template "rsvps"
      end

      def set_data(data, _types)
        webmentions = extract_type "rsvps", data
        @data = { "webmentions" => webmentions.values }
      end
    end
  end
end

Liquid::Template.register_tag("webmention_rsvps", Jekyll::WebmentionIO::WebmentionRsvpsTag)
