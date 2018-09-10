# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_reposts post.url %}
#
module Jekyll
  module WebmentionIO
    class WebmentionRepostsTag < WebmentionTypeTag
      def initialize(tag_name, text, tokens)
        super
        @text = text
        self.template = "reposts"
      end
    end
  end
end

Liquid::Template.register_tag("webmention_reposts", Jekyll::WebmentionIO::WebmentionRepostsTag)
