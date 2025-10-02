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
        @caches = WebmentionIO.caches

        return if WebmentionIO.config.pause_lookups

        WebmentionIO.log "msg", "Collecting webmentions you’ve made. This may take a while."

        posts = WebmentionIO.config.documents.select { |p| !p.data['draft'] }

        gather_webmentions(posts)
      end

      private

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

        target.response_mapping.each do |key, pattern|
          result = pattern.on(response)

          if ! result
            WebmentionIO.log "msg", "The path #{skey} doesn't exist in the response from #{target.endpoint} for #{uri}"
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
        WebmentionIO.config.collections.each do |name, collection|
          next if name == "posts"

          return collection if collection.docs.include? post
        end

        return nil
      end

      def gather_webmentions(posts)
        outgoing = @caches.outgoing_webmentions

        posts.each do |post|
          # Collect potential outgoing webmentions in this post.
          mentions = get_mentioned_uris(post)

          mentions.each do |mentioned_uri, response|
            # If this webmention was a product of a syndication instruction,
            # this goes back into the configuration and pulls that syndication
            # target config out.
            #
            # If this is just a normal webmention, this will return nil.
            target = WebmentionIO.config.syndication_rule_for_uri(mentioned_uri)

            fulluri = File.join(WebmentionIO.config.site_url, post.url)
            shorturi = post.data["shorturl"] || fulluri

            # Old cached responses might use either the full or short URIs so
            # we need to check for both.
            cached_response =
              outgoing.dig(shorturi, mentioned_uri) ||
              outgoing.dig(fulluri, mentioned_uri)

            if cached_response.nil?
              if ! target.nil?
                uri = target["shorturl"] ? shorturi : fulluri

                if target.key? "fragment"
                  uri += "#" + target["fragment"]
                end
              else
                uri = fulluri
              end

              outgoing[uri] ||= {}
              outgoing[uri][mentioned_uri] = response
            elsif ! target.nil?
              process_syndication(post, target, cached_response)
            end
          end
        end

        # This check is moved down here because we still need the steps
        # above to populate frontmatter during the site build, even
        # if we're not going to modify the webmention cache.

        return if WebmentionIO.config.pause_lookups

        outgoing.write
      end

      def get_mentioned_uris(post)
        collection = get_collection_for_post(post)

        uris = {}
        parser = URI::Parser.new

        syndication_targets = []
        syndication_targets += post.data["syndicate_to"] || []

        if ! collection.nil?
          syndication_targets += collection.metadata["syndicate_to"] || []
        end

        syndication_targets.each do |endpoint|
          syn_rule = WebmentionIO.syndication[endpoint]

          if !syn_rule.nil?
            uris[syn_rule.endpoint] = false
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
          begin
            # We do this as a poor man's way to validate the URI.  We do most
            # of the work with the regex scan above, then attempt a parse as
            # the last test in case a bad URI fell through the cracks.
            #
            # Of course, better would be to fix the regex, but consider this
            # belt-and-suspenders...
            parser.parse(parser.escape(match))

            unless uris.key? match
              uris[match] = false
            end
          rescue => e
            WebmentionIO.log "msg", "Encountered unexpected malformed URI '#{match}' in #{post.path}, skipping..."
          end
        end

        return uris
      end
    end
  end
end
