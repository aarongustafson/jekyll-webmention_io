# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator gathers webmentions of your pages
#

require "time"
require_relative "../caches"

module Jekyll
  module WebmentionIO
    class GatherWebmentions < Generator
      safe true
      priority :high

      def generate(site)
        @caches = WebmentionIO.caches

        return if WebmentionIO.config.pause_lookups

        WebmentionIO.log "msg", "Beginning to gather webmentions of your posts. This may take a while."

        WebmentionIO.config.documents.each do |post|
          check_for_webmentions(post)
        end

        @caches.site_lookups.write
        @caches.incoming_webmentions.write
      end

      private

      def check_for_webmentions(post)
        WebmentionIO.log "info", "Checking for webmentions of #{post.url}."

        last_webmention = 
          @caches
          .incoming_webmentions
          .dig(post.url, @caches.incoming_webmentions.dig(post.url)&.keys&.last)

        # get the last webmention
        last_lookup = if @caches.site_lookups[post.url]
                        @caches.site_lookups[post.url]
                      elsif last_webmention
                        Date.parse last_webmention.dig("raw", "verified_date")
                      end

        # should we throttle?
        if post.respond_to? "date" # Some docs have no date
          if last_lookup && WebmentionIO.policy.post_should_be_throttled?(post, post.date, last_lookup)
            WebmentionIO.log "info", "Throttling this post."
            return
          end
        end

        # Get the last id we have in the hash
        since_id = last_webmention ? last_webmention.dig("raw", "id") : false

        # Gather the URLs
        targets = get_webmention_target_urls(post)

        # execute the API
        webmentions = WebmentionIO.webmentions.get_webmentions(targets, since_id)

        @caches.site_lookups[post.url] = Date.today

        cache_new_webmentions(post.url, webmentions)
      end

      def get_webmention_target_urls(post)
        targets = []
        uri = File.join(WebmentionIO.config.site_url, post.url)
        targets.push(uri)

        # Redirection?
        gather_redirected_targets(post, uri, targets)

        # Domain changed?
        gather_legacy_targets(uri, targets)

        targets
      end

      def gather_redirected_targets(post, uri, targets)
        redirected = false
        if post.data.key? "redirect_from"
          if post.data["redirect_from"].is_a? String
            redirected = uri.sub post.url, post.data["redirect_from"]
            targets.push(redirected)
          elsif post.data["redirect_from"].is_a? Array
            post.data["redirect_from"].each do |redirect|
              redirected = uri.sub post.url, redirect
              targets.push(redirected)
            end
          end
        end
      end

      def gather_legacy_targets(uri, targets)
        WebmentionIO.log "info", "Adding any legacy URIs"

        WebmentionIO.config.legacy_domains.each do |domain|
          legacy = uri.sub(WebmentionIO.config.site_url, domain)
          WebmentionIO.log "info", "Adding legacy URI #{legacy}"
          targets.push(legacy)
        end
      end

      def cache_new_webmentions(post_uri, wms)
        webmentions = @caches.incoming_webmentions[post_uri] || {}

        wms.filter { |wm| !webmentions.key?(wm.id) }.each do |wm|
          WebmentionIO.log "info", wm.to_hash.inspect

          webmentions[wm.id] = wm.to_hash
        end

        @caches.incoming_webmentions[post_uri] = webmentions
      end
    end
  end
end
