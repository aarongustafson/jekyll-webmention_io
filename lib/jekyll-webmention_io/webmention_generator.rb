#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo
    
    class WebmentionGenerator < Generator
      safe true
      priority :low
      
      def generate(site)
        webmentions = {}
        if defined?(WEBMENTION_CACHE_DIR)
          cache_file = File.join(WEBMENTION_CACHE_DIR, 'webmentions.yml')
          site.posts.each do |post|
            source = "#{site.config['url']}#{post.url}"
            targets = []
            if post.data['in_reply_to']
              targets.push(post.data['in_reply_to'])
            end
            post.content.scan(/(?:https?:)?\/\/[^\s)#"]+/) do |match|
              if ! targets.find_index( match )
                targets.push(match)
              end
            end
            webmentions[source] = targets
          end
          File.open(cache_file, 'w') { |f| YAML.dump(webmentions, f) }
        end
      end
    end

  end
end
