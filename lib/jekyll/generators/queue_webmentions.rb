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
              unless webmentions[uri].key? mentioned_uri
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
        if post.data["in_reply_to"]
          uris[post.data["in_reply_to"]] = false
        end
        post.content.scan(/(?:https?:)?\/\/[^\s)#\[\]{}<>%|\^"]+/) do |match|
          unless uris.key? match
            uris[match] = false
          end
        end

        %w(mf mf-mp).each do |prefix|
          %w(syndicate-to repost-of like-of in-reply-to bookmark-of).each do |kind|
            if syndicates = post.data["#{prefix}-#{kind}"]
              for syndicate in syndicates
                WebmentionIO.log "info", "Syndicate #{syndicate}."
                uris[syndicate] = false
              end
            end            
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
