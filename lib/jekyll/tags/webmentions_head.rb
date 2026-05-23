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
        config = WebmentionIO.config
        origin = config.api_origin

        head = +'' # unfrozen String
        head << "<link rel=\"dns-prefetch\" href=\"#{origin}\">"
        head << "<link rel=\"preconnect\" href=\"#{origin}\">"
        head << "<link rel=\"preconnect\" href=\"ws://#{config.api_host}:8080\">"

        page = context['page']
        site_url = config.site_url

        if page['redirect_from']
          if page['redirect_from'].is_a? String
            redirect = site_url + page['redirect_from']
          elsif page['redirect_from'].is_a? Array
            redirect = site_url + page['redirect_from'].join(",#{site_url}")
          end
          head << "<meta property=\"webmention:redirected_from\" content=\"#{redirect}\">"
        end

        username = config.username

        if username
          head << "<link rel=\"pingback\" href=\"#{origin}/#{username}/xmlrpc\">"
          head << "<link rel=\"webmention\" href=\"#{origin}/#{username}/webmention\">"
        end

        head
      end
    end
  end
end

Liquid::Template.register_tag('webmentions_head', Jekyll::WebmentionIO::WebmentionHeadTag)
