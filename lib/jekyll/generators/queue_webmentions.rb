#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  This generator caches sites you mention so they can be mentioned
#   
module Jekyll
  class QueueWebmentions < Generator
    include WebmentionIO

    safe true
    priority :low
    
    def generate(site)
      webmentions = {}
      
      site.posts.each do |post|
        source = "#{site.config['url']}#{post.url}"
        targets = []
        if post.data['in_reply_to']
          targets.push(post.data['in_reply_to'])
        end
        post.content.scan(/(?:https?:)?\/\/[^\s)#"]+/) do |match|
          if ! targets.find_index(match)
            targets.push(match)
          end
        end
        webmentions[source] = targets
      end
      File.open(@cache_files['outgoing'], 'w') { |f| YAML.dump(webmentions, f) }
    end

  end
end