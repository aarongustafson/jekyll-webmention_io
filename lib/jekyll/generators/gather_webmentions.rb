# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator gathers webmentions of your pages
#

require "time"

module Jekyll
  module WebmentionIO
    class GatherWebmentions < Generator
      safe true
      priority :high

      def generate(site)
        @site = site
        @site_url = site.config["url"].to_s

        if @site_url.include? "localhost"
          Jekyll::WebmentionIO.log "msg", "Webmentions won’t be gathered on localhost."
          return
        end

        if @site.config.dig("webmentions", "pause_lookups") == true
          WebmentionIO.log "msg", "Webmention gathering is currently paused."
          return
        end

        WebmentionIO.log "msg", "Beginning to gather webmentions of your posts. This may take a while."

        WebmentionIO.api_path = "mentions"
        # add an arbitrarily high perPage to trump pagination
        WebmentionIO.api_suffix = "&perPage=9999"

        @cached_webmentions = WebmentionIO.read_cached_webmentions "incoming"

        @lookups = WebmentionIO.read_lookup_dates

        posts = WebmentionIO.gather_documents(@site)
        posts.each do |post|
          check_for_webmentions(post)
        end

        WebmentionIO.cache_lookup_dates @lookups

        WebmentionIO.cache_webmentions "incoming", @cached_webmentions
      end # generate

      private

      def check_for_webmentions(post)
        WebmentionIO.log "info", "Checking for webmentions of #{post.url}."

        last_webmention = @cached_webmentions.dig(post.url, @cached_webmentions.dig(post.url)&.keys&.last)

        # get the last webmention
        last_lookup = if @lookups[post.url]
                        @lookups[post.url]
                      elsif last_webmention
                        Date.parse last_webmention.dig("raw", "verified_date")
                      end

        # should we throttle?
        if post.respond_to? "date" # Some docs have no date
          if last_lookup && WebmentionIO.post_should_be_throttled?(post, post.date, last_lookup)
            WebmentionIO.log "info", "Throttling this post."
            return
          end
        end

        # Get the last id we have in the hash
        since_id = last_webmention ? last_webmention.dig("raw", "id") : false

        # Gather the URLs
        targets = get_webmention_target_urls(post)

        # execute the API
        response = WebmentionIO.get_response assemble_api_params(targets, since_id)
        webmentions = response.dig("links")
        if webmentions && !webmentions.empty?
          WebmentionIO.log "info", "Here’s what we got back:\n\n#{response.inspect}\n\n"
        else
          WebmentionIO.log "info", "No webmentions found."
        end

        @lookups[post.url] = Date.today
        cache_new_webmentions(post.url, response)
      end

      def get_webmention_target_urls(post)
        targets = []
        uri = File.join(@site_url, post.url)
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
        if WebmentionIO.config.key? "legacy_domains"
          WebmentionIO.log "info", "adding legacy URIs"
          WebmentionIO.config["legacy_domains"].each do |domain|
            legacy = uri.sub(@site_url, domain)
            WebmentionIO.log "info", "adding URI #{legacy}"
            targets.push(legacy)
          end
        end
      end

      def assemble_api_params(targets, since_id)
        api_params = targets.collect { |v| "target[]=#{v}" }.join("&")
        api_params << "&since_id=#{since_id}" if since_id
        api_params << "&sort-by=published"
        api_params
      end

      def cache_new_webmentions(post_uri, response)
        # Get cached webmentions
        webmentions = if @cached_webmentions.key? post_uri
                        @cached_webmentions[post_uri]
                      else
                        {}
                      end

        if response && response["links"]
          response["links"].reverse_each do |link|
            webmention = WebmentionIO::WebmentionItem.new(link, @site)

            # Do we already have it?
            if webmentions.key? webmention.id
              next
            end

            # Add it to the list
            WebmentionIO.log "info", webmention.to_hash.inspect
            webmentions[webmention.id] = webmention.to_hash
          end # each link
        end # if response
        @cached_webmentions[post_uri] = webmentions
      end # process_webmentions
    end
  end
end
