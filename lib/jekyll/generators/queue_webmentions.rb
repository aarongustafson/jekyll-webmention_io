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
			Jekyll::WebmentionIO::log 'info', 'Beginning to gather webmentions you’ve made. This may take a while.'

      webmentions = {}
      
      if Jekyll::VERSION >= "3.0.0"
				posts = site.posts.docs
			else
				posts = site.posts
			end
				
      posts.each do |post|
        uri = "#{site.config['url']}#{post.url}"
        webmentions[uri] = get_mentioned_uris(post)
      end

			cache_file = Jekyll::WebmentionIO::get_cache_file_path 'outgoing'
      File.open(cache_file, 'w') { |f| YAML.dump(webmentions, f) }

			log 'info', 'Webmentions have been gathered and cached.'
    end

    def get_mentioned_uris(post)
			uris = []
			if post.data['in_reply_to']
				uris.push(post.data['in_reply_to'])
			end
			post.content.scan(/(?:https?:)?\/\/[^\s)#"]+/) do |match|
				if ! uris.find_index( match )
					uris.push(match)
				end
			end
    	return uris
		end
    
  end
end