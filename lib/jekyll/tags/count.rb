#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_count post.url [ likes | links | posts | replies | reposts ]*   %}
#
module Jekyll
  module WebmentionIO
    class WebmentionCountTag < Jekyll::WebmentionIO::WebmentionTag
      def initialize(tagName, text, tokens)
        super
        @text = text
        set_template "count"
      end

      def set_data(data, types)
        @data = { "count" => data.length, "types" => types }
      end
    end
  end
end

Liquid::Template.register_tag("webmention_count", Jekyll::WebmentionIO::WebmentionCountTag)
Liquid::Template.register_tag("webmentions_count", Jekyll::WebmentionIO::WebmentionCountTag)
