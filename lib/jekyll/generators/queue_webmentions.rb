# coding: utf-8
# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator caches sites you mention so they can be mentioned
#

module Jekyll
  module WebmentionIO
    class QueueWebmentions < Generator
      safe true
      priority :low

      def generate(site)
        @site = site
        @site_url = site.config["url"].to_s
        @syndication_endpoints = site.config.dig("webmentions", "syndication_endpoints")

        if @site.config['serving']
          Jekyll::WebmentionIO.log "msg", "Webmentions lookups are not run when running `jekyll serve`."
          @site.config['webmentions']['pause_lookups'] = true
          return
        end

        if @site_url.include? "localhost"
          WebmentionIO.log "msg", "Webmentions lookups are not run on localhost."
          return
        end

        if @site.config.dig("webmentions", "pause_lookups")
          WebmentionIO.log "info", "Webmention lookups are currently paused."
          return
        end

        WebmentionIO.log "msg", "Beginning to gather webmentions you’ve made. This may take a while."

        upgrade_outgoing_webmention_cache

        posts = WebmentionIO.gather_documents(@site)

        gather_webmentions(posts)
      end

      private

      def gather_webmentions(posts)
        webmentions = WebmentionIO.read_cached_webmentions "outgoing"

        posts.each do |post|
          uri = File.join(@site_url, post.url)
          mentions = get_mentioned_uris(post)
          if webmentions.key? uri
            mentions.each do |mentioned_uri, response|
              if webmentions[uri].key? mentioned_uri
                # We knew about this target from a previous run

                cached_response = webmentions[uri][mentioned_uri]

                if ! @syndication_endpoints.values.index(mentioned_uri).nil? and
                    cached_response.instance_of? Hash and
                    cached_response.key? "url"

                  # If this is a syndication target, and we have a response,
                  # then the response might include the syndication URL (e.g.
                  # with brid.gy).  Here we pull that out if it exists and add
                  # it to the "syndication" front matter element so that it can
                  # be used in templates.

                  post.data["syndication"] ||= []

                  if post.data["syndication"].instance_of? Array
                    post.data["syndication"].insert(-1, cached_response["url"])
                  end
                end
              else
                # This is a new mention, add the target to the cache
                webmentions[uri][mentioned_uri] = response
              end
            end
          else
            webmentions[uri] = mentions
          end
        end

        WebmentionIO.cache_webmentions "outgoing", webmentions
      end

      def get_mentioned_uris(post)
        uris = {}
        if post.data["syndicate_to"]
          post.data["syndicate_to"].each do |endpoint|
            if @syndication_endpoints.key? endpoint
              uris[@syndication_endpoints[endpoint]] = false
            else
              WebmentionIO.log "msg", "Found reference to syndication endpoint \"#{endpoint}\" without matching entry in configuration."
            end
          end
        end
        if post.data["in_reply_to"]
          uris[post.data["in_reply_to"]] = false
        end
        post.content.scan(/(?:https?:)?\/\/[^\s)#\[\]{}<>%|\^"]+/) do |match|
          unless uris.key? match
            uris[match] = false
          end
        end
        return uris
      end

      def upgrade_outgoing_webmention_cache
        old_sent_file = WebmentionIO.cache_file("sent.yml")
        old_outgoing_file = WebmentionIO.cache_file("queued.yml")
        unless File.exist? old_sent_file
          return
        end
        sent_webmentions = WebmentionIO.load_yaml(old_sent_file)
        outgoing_webmentions = WebmentionIO.load_yaml(old_outgoing_file)
        merged = {}
        outgoing_webmentions.each do |source_url, webmentions|
          collection = {}
          webmentions.each do |target_url|
            collection[target_url] = if sent_webmentions.dig(source_url, target_url)
                                       ""
                                     else
                                       false
                                     end
          end
          merged[source_url] = collection
        end
        WebmentionIO.cache_webmentions "outgoing", merged
        File.delete old_sent_file, old_outgoing_file
        WebmentionIO.log "msg", "Upgraded your sent webmentions cache."
      end
    end
  end
end
