# frozen_string_literal: false

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmentions post.url [ likes | links | posts | replies | reposts ]*  %}
#
module Jekyll
  module WebmentionIO
    class WebmentionsTag < Jekyll::WebmentionIO::WebmentionTag
      def initialize(tag_name, text, tokens)
        super
        @text = text
        set_template "webmentions"
      end
    end
  end
end

Liquid::Template.register_tag("webmentions", Jekyll::WebmentionIO::WebmentionsTag)
