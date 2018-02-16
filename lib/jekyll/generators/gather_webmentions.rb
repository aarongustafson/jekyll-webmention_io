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

      Jekyll::WebmentionIO.set_api_endpoint("mentions")
      # add an arbitrarily high perPage to trump pagination
      Jekyll::WebmentionIO.set_api_suffix("&perPage=9999")

      cache_file = Jekyll::WebmentionIO.get_cache_file_path "incoming"
      @cached_webmentions = open(cache_file) { |f| YAML.load(f) }

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
        # get the last webmention
        last_webmention = @cached_webmentions.dig(post.url, @cached_webmentions.dig(post.url)&.keys&.last)

        # should we throttle?
        if post.respond_to? "date" # Some docs have no date
          if last_webmention && Jekyll::WebmentionIO.post_should_be_throttled?(post, post.date, last_webmention.dig("raw", "verified_date"))
            # Jekyll::WebmentionIO.log 'info', "Throttling #{post.url}"
            next
          end
        end

        # past_webmentions.dig( past_webmentions&.keys&.last )
        # past_webmentions[past_webmentions.keys.last]['raw']['verified_date']

        # Get the last id we have in the hash
        since_id = last_webmention ? last_webmention.dig("raw", "id") : false

        # Gather the URLs
        targets = get_webmention_target_urls(post)

        # execute the API
        api_params = targets.collect { |v| "target[]=#{v}" }.join("&")
        api_params << "&since_id=#{since_id}" if since_id
        response = Jekyll::WebmentionIO.get_response(api_params)
        # Jekyll::WebmentionIO.log "info", response.inspect

        process_webmentions(post.url, response)
      end # posts loop

      File.open(cache_file, "w") { |f| YAML.dump(@cached_webmentions, f) }

      Jekyll::WebmentionIO.log "info", "Webmentions have been gathered and cached."
    end # generate

    def get_webmention_target_urls(post)
      targets = []
      base_uri = @site.config["url"].chomp("/")
      uri = "#{base_uri}#{post.url}"
      targets.push(uri)

      # Redirection?
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

      # Domain changed?
      if Jekyll::WebmentionIO.config.key? "legacy_domains"
        # Jekyll::WebmentionIO.log "info", "adding legacy URIs"
        Jekyll::WebmentionIO.config["legacy_domains"].each do |domain|
          legacy = uri.sub @site.config["url"], domain
          # Jekyll::WebmentionIO.log "info", "adding URI #{legacy}"
          targets.push(legacy)
        end
      end
      return targets
    end

    def process_webmentions(post_uri, response)
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
          # Jekyll::WebmentionIO.log "info", webmention.hash.inspect
          webmentions[webmention.id] = webmention.hash
        end # each link
      end # if response
      @cached_webmentions[post_uri] = webmentions
    end # process_webmentions
  end
end
