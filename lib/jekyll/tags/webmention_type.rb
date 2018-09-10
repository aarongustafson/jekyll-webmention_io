# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/
#
module Jekyll
  module WebmentionIO
    # Superclass for Webmention types:
    # [ bookmarks | likes | links | posts | replies | reposts | rsvps ]
    class WebmentionTypeTag < WebmentionTag
      def set_data(data, _types)
        webmentions = extract_type @template_name, data
        @data = { "webmentions" => webmentions.values }
      end
    end
  end
end
