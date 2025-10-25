# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_replies post.url %}
#
module Jekyll
  module WebmentionIO
    class WebmentionRepliesTag < WebmentionTypeTag
      def initialize(tag_name, text, tokens)
        super
        @text = text
        self.template = 'replies'
      end
    end
  end
end

Liquid::Template.register_tag('webmention_replies', Jekyll::WebmentionIO::WebmentionRepliesTag)
