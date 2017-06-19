#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  This generator gathers webmentions of your pages
#   
module Jekyll
  class GatherWebmentions < Generator
    include WebmentionIO

    safe true
    priority :high
    
    def generate(site)

			set_api_endpoint('mentions')
      # add an arbitrarily high perPage to trump pagination
      set_api_suffix('&perPage=9999')

			if File.exists?(@cache_files['incoming'])
        @cached_webmentions = open(@cache_files['incoming']) { |f| YAML.load(f) }
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
				targets = get_webmention_target_urls("#{site.config['url']}#{post.url}")
        
				# execute the API
      	api_params = targets.collect { |v| "target[]=#{v}" }.join('&')
      	response = get_response(api_params)
      	log 'info', response.inspect
				
				process_webmentions( post.url, response )
      end # posts loop

      File.open(@cache_files['incoming'], 'w') { |f| YAML.dump(@cached_webmentions, f) }
    
		end # generate

    def get_webmention_target_urls(url)
      targets = []
      targets.push(url)
        if @config.has_key? 'legacy_domains'
          log 'info', 'adding legacy URLs'
          @config['legacy_domains'].each do |domain|
            legacy = url.sub @jekyll_config['url'], domain
            log 'info', "adding URL #{legacy}"
            targets.push(legacy)
          end
        end
      return targets
    end

		def process_webmentions( url, response )

			# Get cached webmentions
			if @cached_webmentions.has_key? url
				webmentions = @cached_webmentions[url]
			else
				webmentions = {}
			end

			if response and response['links']
				
				response = response.force_encoding('UTF-8')

				response['links'].reverse_each do |link|
					
					# set the source
					source = false
					if webmention['url'].include? 'twitter.com/'
						source = 'twitter'
					elsif webmention['url'].include? '/googleplus/'
						source = 'googleplus'
					end
					
					# set an id
					id = link['id']
					if webmention['source']=='twitter' and ! url.include? '#favorited-by'
						id = URI(link['data']['url']).path.split('/').last
					end
					if ! id
          	time = Time.now();
          	id = time.strftime('%s')
        	end

					# Do we already have it?
					if key_exists webmentions, id
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
					the_date = pubdate.strftime('%s')

	        # Make sure we have the date
        	if ! webmentions.has_key? the_date
          	webmentions[the_date] = {}
        	end

        	# Make sure we have the webmention
        	# puts "#{target} - #{the_date} - #{id}"
        	if ! webmentions[the_date].has_key? id
						
						# Scaffold the webmention
						webmention = {
							'id'			=> id,
							'content' => link['data']['content'],
							'source'	=> source,
							'pubdate' => pubdate,
							'raw'			=> link
						}

						# Get the url
						url = link['data']['url'] || link['source']
						webmention['url'] = url

						# Set the author
						if link['data'].has_key? 'author'
							webmention['author'] = link['data']['author']
						end

						# Set the type
						type = link['activity']['type']
						if ! type
							if source == 'googleplus'
								switch true
									case url.include? '/like/':
										type = 'like'
										break;
									case url.include? '/repost/':
										type = 'repost'
										break;
									case url.include? '/comment/':
										type = 'reply'
										break;
									default:
										type = 'link'
										break;
								end
							else
								type = 'post'
							end
						end # if no type
						webmention['type'] = type

						# Get the title from Webmention.io or the source URL
						title = link['data']['name']
						if ! title and url

							html_source = get_uri_source(link['source'])
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

						# Add it to the list
						log 'info', webmention.inspect
						webmentions[the_date][id] = webmention

					end # if ID does not exist
				
				end # each link

			end # if response

			@cached_webmentions[url] = webmentions

		end # process_webmentions

  end
end