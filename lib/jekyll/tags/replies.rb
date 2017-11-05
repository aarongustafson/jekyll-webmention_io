#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_replies post.url %}
#
module Jekyll
  module WebmentionIO
    class WebmentionRepliesTag < Jekyll::WebmentionIO::WebmentionTag
      def initialize(tagName, text, tokens)
        super
        @text = text
        set_template "replies"
      end

      def set_data(data, _types)
        webmentions = extract_type "replies", data
        @data = { "webmentions" => webmentions.values }
      end
    end
  end
end

Liquid::Template.register_tag("webmention_replies", Jekyll::WebmentionIO::WebmentionRepliesTag)
