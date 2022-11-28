# coding: utf-8
# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator caches sites you mention so they can be mentioned
#

require "jsonpath"

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

          @site.config['webmentions'] ||= {}
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

        compile_jsonpath_expressions() if ! @syndication.nil?

        WebmentionIO.log "msg", "Beginning to gather webmentions you’ve made. This may take a while."

        upgrade_outgoing_webmention_cache

        posts = WebmentionIO.gather_documents(@site).select { |p| ! p.data["draft"] }
        gather_webmentions(posts)
      end

      private

      def compile_jsonpath_expressions()
        @syndication.each do | target, config |
          next if ! config.key? "response_mapping"

          mapping = config["response_mapping"]

          mapping.clone.each do | key, pattern |
            begin
              mapping[key] = JsonPath.new(pattern)
            rescue StandardError => e
              WebmentionIO.log "error", "Ignoring invalid JsonPath expression #{pattern}: #{e}"

              mapping.delete(key)
            end
          end
        end
      end

      def combine_values(a, b)
        return case [ a.instance_of?(Array), b.instance_of?(Array) ]
          when [ false, false ]
            [ a, b ]
          when [ false, true ]
            [ a ] + b
          when [ true, false ]
            a << b
          when [ true, true ]
            a + b
        end
      end

      def process_syndication(post, target, response)
        # If this is a syndication target, and we have a response,
        # and the syndication entry contains a response mapping, then
        # go through that map and store the selected values into
        # the page front matter.

        response = JSON.generate(response)

        target["response_mapping"].each do |key, pattern|
          result = pattern.on(response)

          if ! result
            WebmentionIO.log "msg", "The path #{skey} doesn't exist in the response from #{target['endpoint']} for #{uri}"
            next
          elsif result.length == 1
            result = result.first
          end

          if post.data[key].nil?
            post.data[key] = result
          else
            post.data[key] = combine_values(post.data[key], result)
          end
        end
      end

      def get_collection_for_post(post)
        @site.collections.each do |name, collection|
          next if name == "posts"

          return collection if collection.docs.include? post
        end

        return nil
      end

      def get_syndication_target(uri)
        return nil if @syndication.nil?

        @syndication.values.detect { |t| t["endpoint"] == uri }
      end

      def gather_webmentions(posts)
        webmentions = WebmentionIO.read_cached_webmentions "outgoing"

        posts.each do |post|
          # Collect potential outgoing webmentions in this post.
          mentions = get_mentioned_uris(post)

          mentions.each do |mentioned_uri, response|
            # If this webmention was a product of a syndication instruction,
            # this goes back into the configuration and pulls that syndication
            # target config out.
            #
            # If this is just a normal webmention, this will return nil.
            target = get_syndication_target(mentioned_uri)

            fulluri = File.join(@site_url, post.url)
            shorturi = post.data["shorturl"] || fulluri

            # Old cached responses might use either the full or short URIs so
            # we need to check for both.
            cached_response =
              webmentions.dig(shorturi, mentioned_uri) ||
              webmentions.dig(fulluri, mentioned_uri)

            if cached_response.nil?
              uri = (! target.nil? and target["shorturl"]) ? shorturi : fulluri

              webmentions[uri] ||= {}
              webmentions[uri][mentioned_uri] = response
            elsif ! target.nil? and target.key? "response_mapping"
              process_syndication(post, target, cached_response)
            end
          end
        end

        WebmentionIO.cache_webmentions "outgoing", webmentions
      end

      def get_mentioned_uris(post)
        collection = get_collection_for_post(post)

        uris = {}

        syndication_targets = []
        syndication_targets += post.data["syndicate_to"] || []

        if ! collection.nil?
          syndication_targets += collection.metadata["syndicate_to"] || []
        end

        syndication_targets.each do |endpoint|
          if @syndication.key? endpoint
            uris[@syndication[endpoint]["endpoint"]] = false
          else
            WebmentionIO.log "msg", "Found reference to syndication endpoint \"#{endpoint}\" without matching entry in configuration."
          end
        end

        if post.data["in_reply_to"]
          uris[post.data["in_reply_to"]] = false
        end

        if post.data["bookmark_of"]
          uris[post.data["bookmark_of"]] = false
        end

        post.content.scan(/(?:https?:)?\/\/[^\s)#\[\]{}<>%|\^"']+/) do |match|
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
