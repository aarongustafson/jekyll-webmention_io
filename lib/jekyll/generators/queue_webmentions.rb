# frozen_string_literal: false

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
      @site = site

      if @site.config.dig("webmentions", "pause_lookups")
        Jekyll::WebmentionIO.log "info", "Webmention lookups are currently paused."
        return
      end

      Jekyll::WebmentionIO.log "msg", "Beginning to gather webmentions you’ve made. This may take a while."

      upgrade_outgoing_webmention_cache

      posts = Jekyll::WebmentionIO.gather_documents(@site)

      gather_webmentions(posts)
    end

    private

    def gather_webmentions(posts)
      webmentions = Jekyll::WebmentionIO.read_cached_webmentions "outgoing"

      base_uri = @site.config["url"].chomp("/")

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

      Jekyll::WebmentionIO.cache_webmentions "outgoing", webmentions
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
      Jekyll::WebmentionIO.cache_webmentions "outgoing", merged
      File.delete old_sent_file, old_outgoing_file
      Jekyll::WebmentionIO.log "msg", "Upgraded your sent webmentions cache."
    end
  end
end
