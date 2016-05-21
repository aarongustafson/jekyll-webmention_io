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

          # Support both Jekyll 2.x & 3.x
          if defined? site.posts.docs
            site_posts = site.posts.docs # 3.x
          else
            site_posts = site.posts # 2.x
          end

          site_posts.each do |post|
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
