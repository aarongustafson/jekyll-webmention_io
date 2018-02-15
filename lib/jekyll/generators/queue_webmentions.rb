# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  This generator caches sites you mention so they can be mentioned
#

module Jekyll
  class QueueWebmentions < Generator
    safe true
    priority :low

    def generate(site)
      if site.config.dig("webmentions", "pause_lookups") == true
        Jekyll::WebmentionIO.log "info", "Webmention lookups are currently paused."
        return
      end

      Jekyll::WebmentionIO.log "info", "Beginning to gather webmentions you’ve made. This may take a while."

      upgrade_outgoing_webmention_cache

      cache_file = Jekyll::WebmentionIO.get_cache_file_path "outgoing"
      webmentions = open(cache_file) { |f| YAML.load(f) }

      posts = if Jekyll::VERSION >= "3.0.0"
                site.posts.docs.clone
              else
                site.posts.clone
              end

      if site.config.dig("webmentions", "pages") == true
        Jekyll::WebmentionIO.log "info", "Including site pages."
        posts.concat site.pages.clone
      end

      base_uri = site.config["url"].chomp("/")
      posts.each do |post|
        uri = "#{base_uri}#{post.url}"
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

      cache_file = Jekyll::WebmentionIO.get_cache_file_path "outgoing"
      File.open(cache_file, "w") { |f| YAML.dump(webmentions, f) }

      Jekyll::WebmentionIO.log "info", "Webmentions have been gathered and cached."
    end

    def upgrade_outgoing_webmention_cache
      old_sent_file = "#{Jekyll::WebmentionIO.cache_folder}/#{Jekyll::WebmentionIO.file_prefix}sent.yml"
      old_outgoing_file = "#{Jekyll::WebmentionIO.cache_folder}/#{Jekyll::WebmentionIO.file_prefix}queued.yml"
      unless File.exist? old_sent_file
        return
      end
      sent_webmentions = open(old_sent_file) { |f| YAML.load(f) }
      outgoing_webmentions = open(old_outgoing_file) { |f| YAML.load(f) }
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
      cached_outgoing = Jekyll::WebmentionIO.get_cache_file_path "outgoing"
      File.open(cached_outgoing, "w") { |f| YAML.dump(merged, f) }
      File.delete old_sent_file, old_outgoing_file
      Jekyll::WebmentionIO.log "info", "Upgraded your sent webmentions cache."
    end

    def get_mentioned_uris(post)
      uris = {}
      if post.data["in_reply_to"]
        uris[post.data["in_reply_to"]] = false
      end
      post.content.scan(/(?:https?:)?\/\/[^\s)#"]+/) do |match|
        unless uris.key? match
          uris[match] = false
        end
      end
      return uris
    end
  end
end
