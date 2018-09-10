# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  Stuff for the `head`
#

module Jekyll
  module WebmentionIO
    class WebmentionHeadTag < Liquid::Tag
      def render(context)
        head = +"" # unfrozen String
        head << '<link rel="dns-prefetch" href="https://webmention.io">'
        head << '<link rel="preconnect" href="https://webmention.io">'
        head << '<link rel="preconnect" href="ws://webmention.io:8080">'

        page = context["page"]
        site = context.registers[:site]
        if page["redirect_from"]
          if page["redirect_from"].is_a? String
            redirect = site.config["url"] + page["redirect_from"]
          elsif page["redirect_from"].is_a? Array
            redirect = site.config["url"] + page["redirect_from"].join(",#{site.config["url"]}")
          end
          head << "<meta property=\"webmention:redirected_from\" content=\"#{redirect}\">"
        end

        username = site.config.dig("webmentions", "username")
        if username
          head << "<link rel=\"pingback\" href=\"https://webmention.io/#{username}/xmlrpc\">"
          head << "<link rel=\"webmention\" href=\"https://webmention.io/#{username}/webmention\">"
        end

        head
      end
    end
  end
end

Liquid::Template.register_tag("webmentions_head", Jekyll::WebmentionIO::WebmentionHeadTag)
