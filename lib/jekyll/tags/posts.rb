# frozen_string_literal: false

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_posts post.url %}
#
module Jekyll
  module WebmentionIO
    class WebmentionPostsTag < WebmentionTag
      def initialize(tag_name, text, tokens)
        super
        @text = text
        self.template = "posts"
      end

      def set_data(data, _types)
        webmentions = extract_type "posts", data
        @data = { "webmentions" => webmentions.values }
      end
    end
  end
end

Liquid::Template.register_tag("webmention_posts", Jekyll::WebmentionIO::WebmentionPostsTag)
