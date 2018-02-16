# frozen_string_literal: false

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator gathers webmentions of your pages
#

require "time"

module Jekyll
  class GatherWebmentions < Generator
    safe true
    priority :high

    def generate(site)
      @site = site

      if @site.config.dig("webmentions", "pause_lookups") == true
        Jekyll::WebmentionIO.log "info", "Webmention lookups are currently paused."
        return
      end

      Jekyll::WebmentionIO.log "info", "Beginning to gather webmentions of your posts. This may take a while."

      Jekyll::WebmentionIO.api_path = "mentions"
      # add an arbitrarily high perPage to trump pagination
      Jekyll::WebmentionIO.api_suffix = "&perPage=9999"

      @cached_webmentions = Jekyll::WebmentionIO.read_cached_webmentions "incoming"

      posts = if Jekyll::VERSION >= "3.0.0"
                @site.posts.docs.clone
              else
                @site.posts.clone
              end

      if @site.config.dig("webmentions", "pages") == true
        Jekyll::WebmentionIO.log "info", "Including site pages."
        posts.concat @site.pages.clone
      end

      posts.each do |post|
        check_for_webmentions(post)
      end

      Jekyll::WebmentionIO.cache_webmentions "incoming", @cached_webmentions
    end # generate

    private

    def check_for_webmentions(post)
      # get the last webmention
      last_webmention = @cached_webmentions.dig(post.url, @cached_webmentions.dig(post.url)&.keys&.last)

      # should we throttle?
      if post.respond_to? "date" # Some docs have no date
        if last_webmention && Jekyll::WebmentionIO.post_should_be_throttled?(post, post.date, last_webmention.dig("raw", "verified_date"))
          # Jekyll::WebmentionIO.log 'info', "Throttling #{post.url}"
          return
        end
      end

      # Get the last id we have in the hash
      since_id = last_webmention ? last_webmention.dig("raw", "id") : false

      # Gather the URLs
      targets = get_webmention_target_urls(post)

      # execute the API
      response = Jekyll::WebmentionIO.get_response assemble_api_params(targets, since_id)
      # Jekyll::WebmentionIO.log "info", response.inspect

      cache_new_webmentions(post.url, response)
    end

    def get_webmention_target_urls(post)
      targets = []
      base_uri = @site.config["url"].chomp("/")
      uri = "#{base_uri}#{post.url}"
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
      if Jekyll::WebmentionIO.config.key? "legacy_domains"
        # Jekyll::WebmentionIO.log "info", "adding legacy URIs"
        Jekyll::WebmentionIO.config["legacy_domains"].each do |domain|
          legacy = uri.sub @site.config["url"], domain
          # Jekyll::WebmentionIO.log "info", "adding URI #{legacy}"
          targets.push(legacy)
        end
      end
    end

    def assemble_api_params(targets, since_id)
      api_params = targets.collect { |v| "target[]=#{v}" }.join("&")
      api_params << "&since_id=#{since_id}" if since_id
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
          webmention = Jekyll::WebmentionIO::Webmention.new(link, @site)

          # Do we already have it?
          if webmentions.key? webmention.id
            next
          end

          # Add it to the list
          # Jekyll::WebmentionIO.log "info", webmention.to_hash.inspect
          webmentions[webmention.id] = webmention.to_hash
        end # each link
      end # if response
      @cached_webmentions[post_uri] = webmentions
    end # process_webmentions
  end
end
