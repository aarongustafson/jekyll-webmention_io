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
      
      if Jekyll::VERSION >= "3.0.0"
				posts = site.posts.docs
			else
				posts = site.posts
			end
				
      posts.each do |post|
        url = "#{site.config['url']}#{post.url}"
        webmentions[url] = get_mentioned_urls(post)
      end

      File.open(@cache_files['outgoing'], 'w') { |f| YAML.dump(webmentions, f) }
    end

    def get_mentioned_urls(post)
			urls = []
			if post.data['in_reply_to']
				urls.push(post.data['in_reply_to'])
			end
			post.content.scan(/(?:https?:)?\/\/[^\s)#"]+/) do |match|
				if ! urls.find_index( match )
					urls.push(match)
				end
			end
    	return urls
		end
    
  end
end