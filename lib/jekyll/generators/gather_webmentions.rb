#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  This generator gathers webmentions of your pages
#

module Jekyll
  class GatherWebmentions < Generator
    
    safe true
    priority :high
    
    def generate(site)
			@webmention_io = WebmentionIO.new
			
			@webmention_io.set_api_endpoint('mentions')
      # add an arbitrarily high perPage to trump pagination
      @webmention_io.set_api_suffix('&perPage=9999')

			cache_file = @webmention_io.get_cache_file_path 'incoming'
			if File.exists?(cache_file)
        @cached_webmentions = open(cache_file) { |f| YAML.load(f) }
      else
        @cached_webmentions = {}
      end
			
			if Jekyll::VERSION >= "3.0.0"
				posts = site.posts.docs
			else
				posts = site.posts
			end
				
      posts.each do |post|
				# Gather the URLs
				targets = get_webmention_target_urls(site, post)
        
				# execute the API
      	api_params = targets.collect { |v| "target[]=#{v}" }.join('&')
      	response = @webmention_io.get_response(api_params)
      	# @webmention_io.log 'info', response.inspect
				
				process_webmentions( post.url, response )
      end # posts loop

      File.open(cache_file, 'w') { |f| YAML.dump(@cached_webmentions, f) }
    
		end # generate

    def get_webmention_target_urls(site, post)
      targets = []
      url = "#{site.config['url']}#{post.url}"
			targets.push( url )
			
			# Redirection?
			redirected = false
			if post.data.has_key? 'redirect_from'
				redirected = url.sub post.url, post.data['redirect_from']
				targets.push( redirected )
			end
			
			# Domain changed?
			if @webmention_io.config.has_key? 'legacy_domains'
				@webmention_io.log 'info', 'adding legacy URLs'
				@webmention_io.config['legacy_domains'].each do |domain|
					legacy = url.sub site.config['url'], domain
					@webmention_io.log 'info', "adding URL #{legacy}"
					targets.push(legacy)
				end
			end
      return targets
    end

		def process_webmentions( post_url, response )

			# Get cached webmentions
			if @cached_webmentions.has_key? post_url
				webmentions = @cached_webmentions[post_url]
			else
				webmentions = {}
			end

			if response and response['links']
				
				response['links'].reverse_each do |link|
					
					# puts link.inspect
					url = link['data']['url'] || link['source']

					# set the source
					source = false
					if url.include? 'twitter.com/'
						source = 'twitter'
					elsif url.include? '/googleplus/'
						source = 'googleplus'
					end
					
					# set an id
					id = link['id'].to_s
					if source == 'twitter' and ! url.include? '#favorited-by'
						id = URI(url).path.split('/').last.to_s
					end
					if ! id
          	time = Time.now();
          	id = time.strftime('%s').to_s
        	end

					# Do we already have it?
					if webmentions.has_key? id
						next
					end

					# Get the mentioned URI, stripping fragments and query strings
        	#target = URI::parse( link['target'] )
        	#target.fragment = target.query = nil
        	#target = target.to_s
        
        	pubdate = link['data']['published_ts']
        	if pubdate
          	pubdate = Time.at(pubdate)
        	elsif link['verified_date']
          	pubdate = Time.parse(link['verified_date'])
        	end
					#the_date = pubdate.strftime('%s')

	        # Make sure we have the date
        	# if ! webmentions.has_key? the_date
          # 	webmentions[the_date] = {}
        	# end

        	# Make sure we have the webmention
        	# puts "#{target} - #{the_date} - #{id}"
        	# if ! webmentions[the_date].has_key? id
					if ! webmentions.has_key? id
						
						# Scaffold the webmention
						webmention = {
							'id'			=> id,
							'url'			=> url,
							'source'	=> source,
							'pubdate' => pubdate,
							'raw'			=> link
						}

						# Set the author
						if link['data'].has_key? 'author'
							webmention['author'] = link['data']['author']
						end

						# Set the type
						type = link['activity']['type']
						if ! type
							if source == 'googleplus'
								if url.include? '/like/'
									type = 'like'
								elsif url.include? '/repost/'
									type = 'repost'
								elsif url.include? '/comment/'
									type = 'reply'
								else
									type = 'link'
								end
							else
								type = 'post'
							end
						end # if no type
						webmention['type'] = type

						# Posts
						title = false
						if type == 'post'

							html_source = @webmention_io.get_uri_source( url )
              if ! html_source
                next
              end
							
							if ! html_source.valid_encoding?
                html_source = html_source.encode('UTF-16be', :invalid=>:replace, :replace=>"?").encode('UTF-8')
              end

							# Check the `title` first
              matches = /<title>(.*)<\/title>/.match( html_source )
              if matches
                title = matches[1].strip
              else
								# Fall back to the first `h1`
								matches = /<h1>(.*)<\/h1>/.match( html_source )
                if matches
                  title = matches[1].strip
                else
									# No title found
                  title = 'No title available'
                end
              end
              
							# cleanup
              title = title.gsub(%r{</?[^>]+?>}, '')
						end # if no title
						webmention['title'] = title

						# Everything else
						content = link['data']['content']
						if ! content && type != 'post'
							content = link['activity']['sentence_html']
						end
						webmention['content'] = content

						# Add it to the list
						# @webmention_io.log 'info', webmention.inspect
						# webmentions[the_date][id] = webmention
						webmentions[id] = webmention

					end # if ID does not exist
				
				end # each link

			end # if response

			@cached_webmentions[post_url] = webmentions

		end # process_webmentions

  end
end