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
      WebmentionIO.log 'info', 'Beginning to gather webmentions you’ve made. This may take a while.'

      webmentions = {}

      posts = if Jekyll::VERSION >= '3.0.0'
                site.posts.docs
              else
                site.posts
                 end

      posts.each do |post|
        uri = "#{site.config['url']}#{post.url}"
        webmentions[uri] = get_mentioned_uris(post)
      end

      cache_file = WebmentionIO.get_cache_file_path 'outgoing'
      File.open(cache_file, 'w') { |f| YAML.dump(webmentions, f) }

      WebmentionIO.log 'info', 'Webmentions have been gathered and cached.'
    end

    def get_mentioned_uris(post)
      uris = []
      uris.push(post.data['in_reply_to']) if post.data['in_reply_to']
      post.content.scan(/(?:https?:)?\/\/[^\s)#"]+/) do |match|
        uris.push(match) unless uris.find_index(match)
      end
      uris
    end
  end
end
