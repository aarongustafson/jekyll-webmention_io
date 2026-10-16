# frozen_string_literal: true

#  (c) Brett Kosinski
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  Collects the webmentions webmention.io holds for a batch of targets
#
module Jekyll
  module WebmentionIO
    # One post, and the URLs it answers to: its own URL, plus any redirect_from and
    # legacy-domain spellings. `canonical_urls` are the other spellings webmention.io has
    # reported for that post: the service answers with the URL it filed a post under
    # rather than the URL that was asked about, so an answer is matched against these as
    # well.
    Target = Struct.new(:post, :urls, :since_id, :canonical_urls, keyword_init: true)

    class WebmentionCollector
      # webmention.io takes at most 50 `target[]` values in one request, and answers 429
      # once a client address exceeds a request rate, so ask about as many URLs as one
      # request will carry and no more. A target holds one URL per spelling its post
      # answers to, so the caller budgets URLs rather than posts, and a batch over the
      # limit that could have been cut smaller is refused rather than sent.
      MAX_URLS_PER_REQUEST = 50

      def initialize(webmentions)
        @webmentions = webmentions
      end

      # Asks about a batch of targets and returns the mentions it found, keyed by the
      # URL of the post each one belongs to. Every post that answered is a key, holding
      # an empty list when there was nothing new for it; a post missing from the map is
      # one whose request failed, so its lookup should not be recorded and it should be
      # asked about again.
      #
      # The batch is the caller's to build and the caller's to get right: one
      # `since_id` covers a whole request, so every target in a batch must be as cold
      # as the rest, and the batch must be no larger than one request will carry.
      def lookup(targets)
        if targets.map(&:urls).sum(&:length) > MAX_URLS_PER_REQUEST
          raise ArgumentError, "too many URLs in one request; webmention.io takes at most #{MAX_URLS_PER_REQUEST}."
        end

        if targets.map(&:since_id).uniq(&:nil?).length > 1
          raise ArgumentError, 'a batch mixing targets with and without a since_id would ask from the wrong wm-id; batch the two kinds separately.'
        end

        gather_mentions(targets)
      end

      private

      # The batch's mentions by post URL, or an empty map as soon as a request fails. One
      # request covers the whole batch while every URL the answer names is one we know; an
      # answer naming a URL that matches nothing is redone a post at a time instead, where
      # everything a post is told belongs to that post.
      def gather_mentions(targets)
        mentions = fetch_mentions(targets)

        return {} if mentions.nil?

        (result, unmatched) = match_mentions(targets, mentions)

        unmatched.each do |url|
          WebmentionIO.log 'info', "webmention.io filed a mention under #{url}, which is not a URL that was asked about nor one it has reported for these posts before; asking these posts one at a time."
        end

        unmatched.empty? ? result : fetch_by_post(targets)
      end

      # Every mention the batch's posts have for us, page by page, or nil as soon as
      # one fails. A request can hold more mentions than one page carries, so stopping
      # at the first page would drop the rest; and a failed call is not a completed
      # lookup, so the caller leaves those posts to be retried rather than recorded.
      def fetch_mentions(targets)
        urls = targets.flat_map(&:urls)
        since_id = targets.map(&:since_id).compact.min
        page = 0
        total_pages = 1
        mentions = []

        while page < total_pages
          result = @webmentions.get_webmentions(urls, since_id, page)

          unless result.success?
            WebmentionIO.log 'info', "the lookup failed on page #{page}; nothing was recorded for these #{targets.length} posts, and they will be asked about again."

            return nil
          end

          mentions.concat(result.items)

          total_pages = result.total_pages
          page += 1
        end

        mentions
      end

      # Files each mention against the post that owns the URL webmention.io filed it
      # under, and reports the URLs that matched nothing. That URL need not be one of the
      # URLs asked about: the service matches posts by alias too, so an answer is matched
      # against the spellings already reported for these posts as well.
      #
      # Every post that was asked about is a key, holding an empty list when the answer had
      # nothing for it.
      def match_mentions(targets, mentions)
        posts = post_urls_by_url(targets)
        result = targets.to_h { |target| [target.post.url, []] }
        unmatched = Set.new

        mentions.each do |webmention|
          url = normalize_url(webmention.target)
          post_url = posts[url]

          if post_url.nil?
            unmatched << url
          else
            result[post_url] << webmention
          end
        end

        [result, unmatched]
      end

      # The same mentions by post URL, a post at a time. The request is the match: the
      # service answered with these mentions because they belong to the post that asked, so
      # whatever URL it filed them under is learned here. A post whose request failed is
      # left out.
      def fetch_by_post(targets)
        targets.filter_map do |target|
          mentions = fetch_mentions([target])

          [target.post.url, mentions] unless mentions.nil?
        end.to_h
      end

      # Maps every URL an answer might name to the post that owns it: the URLs the batch
      # asked about, plus the spellings webmention.io has already reported for those
      # posts. A post's own URL arrives twice when the service reports it among those
      # spellings, which lands on the same post either way.
      def post_urls_by_url(targets)
        posts = {}

        targets.each do |target|
          post_url = target.post.url

          (target.urls + target.canonical_urls)
            .map { |url| normalize_url(url) }
            .each { |url| posts[url] = post_url }
        end

        posts
      end

      def normalize_url(url)
        url.to_s.split('#').first.to_s
      end
    end
  end
end
