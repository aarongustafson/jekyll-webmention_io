# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_rsvps post.url %}
#
module Jekyll
  module WebmentionIO
    class WebmentionRsvpsTag < WebmentionTypeTag
      def initialize(tag_name, text, tokens)
        super
        @text = text
        self.template = "rsvps"
      end
    end
  end
end

Liquid::Template.register_tag("webmention_rsvps", Jekyll::WebmentionIO::WebmentionRsvpsTag)
