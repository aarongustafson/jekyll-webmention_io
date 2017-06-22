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
			WebmentionIO.log 'info', 'Beginning to gather webmentions of your posts. This may take a while.'
			
			WebmentionIO.set_api_endpoint('mentions')
      # add an arbitrarily high perPage to trump pagination
      WebmentionIO.set_api_suffix('&perPage=9999')

			cache_file = WebmentionIO.get_cache_file_path 'incoming'
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

			# post Jekyll commit 0c0aea3
      # https://github.com/jekyll/jekyll/commit/0c0aea3ad7d2605325d420a23d21729c5cf7cf88
      if defined? site.find_converter_instance
        @converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
      # Prior to Jekyll commit 0c0aea3
      else
        @converter = site.getConverterImpl(::Jekyll::Converters::Markdown)
      end
				
      posts.each do |post|
				# Gather the URLs
				targets = get_webmention_target_urls(site, post)
        
				# execute the API
      	api_params = targets.collect { |v| "target[]=#{v}" }.join('&')
      	response = WebmentionIO.get_response(api_params)
      	# @webmention_io.log 'info', response.inspect
				
				process_webmentions( post.url, response )
      end # posts loop

      File.open(cache_file, 'w') { |f| YAML.dump(@cached_webmentions, f) }
			
			WebmentionIO.log 'info', 'Webmentions have been gathered and cached.'
		end # generate

    def get_webmention_target_urls(site, post)
      targets = []
      uri = "#{site.config['url']}#{post.url}"
			targets.push( uri )
			
			# Redirection?
			redirected = false
			if post.data.has_key? 'redirect_from'
				redirected = uri.sub post.url, post.data['redirect_from']
				targets.push( redirected )
			end
			
			# Domain changed?
			if WebmentionIO.config.has_key? 'legacy_domains'
				# WebmentionIO.log 'info', 'adding legacy URIs'
				WebmentionIO.config['legacy_domains'].each do |domain|
					legacy = uri.sub site.config['url'], domain
					# WebmentionIO.log 'info', "adding URI #{legacy}"
					targets.push(legacy)
				end
			end
      return targets
    end

		def markdownify( string )
			string = @converter.convert("#{string}")
			if ! string.start_with?('<p')
				string = string.sub(/^<[^>]+>/, '<p>').sub(/<\/[^>]+>$/, '</p>')
			end
			string.strip
		end

		def process_webmentions( post_uri, response )

			# Get cached webmentions
			if @cached_webmentions.has_key? post_uri
				webmentions = @cached_webmentions[post_uri]
			else
				webmentions = {}
			end

			if response and response['links']
				
				response['links'].reverse_each do |link|
					
					uri = link['data']['url'] || link['source']

					# set the source
					source = false
					if uri.include? 'twitter.com/'
						source = 'twitter'
					elsif uri.include? '/googleplus/'
						source = 'googleplus'
					end
					
					# set an id
					id = link['id'].to_s
					if source == 'twitter' and ! uri.include? '#favorited-by'
						id = URI(uri).path.split('/').last.to_s
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
        	if ! webmentions.has_key? id
						
						# Scaffold the webmention
						webmention = {
							'id'			=> id,
							'url'			=> uri,
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
								if uri.include? '/like/'
									type = 'like'
								elsif uri.include? '/repost/'
									type = 'repost'
								elsif uri.include? '/comment/'
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

							html_source = WebmentionIO.get_uri_source( uri )
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
						webmention['title'] = markdownify( title )

						# Everything else
						content = link['data']['content']
						if type != 'post' && type != 'reply' && type != 'link'
							content = link['activity']['sentence_html']
						end
						webmention['content'] = markdownify( content )

						# Add it to the list
						# @webmention_io.log 'info', webmention.inspect
						webmentions[id] = webmention

					end # if ID does not exist
				
				end # each link

			end # if response

			@cached_webmentions[post_uri] = webmentions

		end # process_webmentions

  end
end