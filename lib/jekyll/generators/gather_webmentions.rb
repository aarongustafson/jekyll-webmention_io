# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator gathers webmentions of your pages
#

require 'time'
require_relative '../caches'
require_relative '../webmention_collector'

module Jekyll
  module WebmentionIO
    class GatherWebmentions < Generator
      safe true
      priority :high

      # How long a post counts as new, in days. A post the service has never answered for
      # has no URL spellings on record, so its first mention arrives filed under a URL an
      # answer cannot be matched against -- and an unmatched answer sends the whole batch
      # back to be redone a post at a time. New posts are the ones whose first mentions are
      # still arriving, so they are looked up on their own.
      NEW_POST_WINDOW = 2

      def generate(_ = nil)
        @caches = WebmentionIO.caches

        return if WebmentionIO.config.pause_lookups

        @collector = WebmentionCollector.new(WebmentionIO.webmentions)

        WebmentionIO.log 'msg', 'Beginning to gather webmentions of your posts. This may take a while.'

        targets = WebmentionIO.config.documents.filter_map { |post| get_webmention_target(post) }
        solo, batched = targets.partition { |target| needs_own_request?(target) }

        requests = solo.map { |target| [target] }

        # One since_id covers a whole request, so posts whose mentions have already been
        # seen are batched apart from posts the service has never answered for.
        requests += batched.partition(&:since_id).flat_map { |group| batches(group) }

        requests.each { |batch| gather(batch) }

        @caches.site_lookups.write
        @caches.incoming_webmentions.write
      end

      private

      def needs_own_request?(target)
        target.canonical_urls.empty? && recently_published?(target.post)
      end

      def recently_published?(post)
        return false unless post.respond_to?('date') && post.date

        post.date.to_date > Date.today - NEW_POST_WINDOW
      end

      # A request may carry MAX_URLS_PER_REQUEST `target[]` values, and a target holds one
      # URL per spelling its post answers to, so a batch is cut by URL count rather than by
      # post. A target is never split, so a post with more spellings than one request may
      # carry goes on its own.
      def batches(targets)
        limit = WebmentionCollector::MAX_URLS_PER_REQUEST

        targets.each_with_object([]) do |target, batches|
          if batches.empty? || batches.last.sum { |held| held.urls.length } + target.urls.length > limit
            batches << [target]
          else
            batches.last << target
          end
        end
      end

      # Asks the collector about one batch, then files what came back and records the
      # lookup, post by post. A post the collector did not return is one whose request
      # failed: it is left unrecorded, to be asked about again rather than throttled.
      def gather(targets)
        @collector.lookup(targets).each do |post_url, mentions|
          mentions.each { |webmention| cache_new_webmention(post_url, webmention) }

          @caches.site_lookups.store(post_url, Date.today)
        end
      end

      # The post's target, or nil when the post is throttled and should not be asked
      # about at all.
      def get_webmention_target(post)
        WebmentionIO.log 'info', "Checking for webmentions of #{post.url}."

        incoming = @caches.incoming_webmentions[post.url]
        last_lookup = @caches.site_lookups[post.url]&.last_check_date || incoming&.last_heard_at

        # should we throttle?
        if post.respond_to?('date') && last_lookup && WebmentionIO.policy.post_should_be_throttled?(post, post.date, last_lookup)
          WebmentionIO.log 'info', 'Throttling this post.'

          return nil
        end

        # The URL spellings webmention.io has already reported for this post, which an
        # answer may name instead of the URL that was asked about.
        canonical_urls = incoming&.canonical_urls || []

        Target.new(post: post, urls: get_webmention_target_urls(post), since_id: incoming&.highest_id, canonical_urls: canonical_urls)
      end

      def get_webmention_target_urls(post)
        urls = []
        uri = File.join(WebmentionIO.config.site_url, post.url)
        urls.push(uri)

        # Redirection?
        gather_redirected_targets(post, uri, urls)

        # Domain changed?
        gather_legacy_targets(uri, urls)

        urls
      end

      def gather_redirected_targets(post, uri, urls)
        redirected = false

        return unless post.data.key? 'redirect_from'

        if post.data['redirect_from'].is_a? String
          redirected = uri.sub post.url, post.data['redirect_from']
          urls.push(redirected)
        elsif post.data['redirect_from'].is_a? Array
          post.data['redirect_from'].each do |redirect|
            redirected = uri.sub post.url, redirect
            urls.push(redirected)
          end
        end
      end

      def gather_legacy_targets(uri, urls)
        WebmentionIO.log 'info', 'Adding any legacy URIs'

        WebmentionIO.config.legacy_domains.each do |domain|
          legacy = uri.sub(WebmentionIO.config.site_url, domain)
          WebmentionIO.log 'info', "Adding legacy URI #{legacy}"
          urls.push(legacy)
        end
      end

      def cache_new_webmention(post_uri, webmention)
        webmentions = @caches.incoming_webmentions.entry(post_uri).webmentions

        return if webmentions.key?(webmention.id)

        WebmentionIO.log 'info', webmention.to_hash.inspect

        webmentions[webmention.id] = webmention.to_hash
      end
    end
  end
end
