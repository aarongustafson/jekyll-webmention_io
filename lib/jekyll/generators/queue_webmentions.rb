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
        @syndication = site.config.dig("webmentions", "syndication")

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

      def process_syndication(post, uri, target, response)
        # If this is a syndication target, and we have a response,
        # and the syndication entry contains a response mapping, then
        # go through that map and store the selected values into
        # the page front matter.

        target["response_mapping"].each do |skey, tkey|
          parts = skey.split(".")
          value = response

          parts.each do |part|
            if value.instance_of? Hash
              value = value[part]
            else
              # Uhoh!  The path doesn't exist, so throw an error and
              # give up on this mapping entry
              WebmentionIO.log "msg", "The path #{skey} doesn't exist in the response from #{target['endpoint']} for #{uri}"

              value = nil
              break
            end
          end

          if ! value.nil?
            if post.data[tkey].nil?
              post.data[tkey] = value
            elsif ! post.data[tkey].instance_of? Array
              post.data[tkey] = [ post.data[tkey], value ]
            else
              post.data[tkey].insert(-1, value)
            end
          end
        end
      end

      def get_collection_for_post(post)
        @site.collections.each do |name, collection|
          if collection.docs.include? post
            return collection
          end
        end

        return nil
      end

      def gather_webmentions(posts)
        webmentions = WebmentionIO.read_cached_webmentions "outgoing"

        posts.each do |post|
          uri = File.join(@site_url, post.url)
          mentions = get_mentioned_uris(post)
          if webmentions.key? uri
            mentions.each do |mentioned_uri, response|
              if webmentions[uri].key? mentioned_uri
                # We knew about this target from a previous run

                next if @syndication.nil?

                target = @syndication.values.detect { |t|
                  t["endpoint"] == mentioned_uri
                }

                response = webmentions[uri][mentioned_uri]

                if ! target.nil? and target.key? "response_mapping"
                  process_syndication(post, uri, target, response)
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
        collection = get_collection_for_post(post)

        uris = {}

        syndication_targets = []
        syndication_targets += post.data["syndicate_to"] || []
        syndication_targets += collection.metadata["syndicate_to"] || []

        syndication_targets.each do |endpoint|
          if @syndication.key? endpoint
            url = @syndication[endpoint]["endpoint"]

            WebmentionIO.log "msg", "Syndication target found: #{url}"

            uris[@syndication[endpoint]["endpoint"]] = false
          else
            WebmentionIO.log "msg", "Found reference to syndication endpoint \"#{endpoint}\" without matching entry in configuration."
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
