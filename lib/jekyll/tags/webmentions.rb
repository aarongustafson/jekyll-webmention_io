#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmentions URL %}
#   
module Jekyll
  class WebmentionsTag < WebmentionTag
  
    def initialize(tagName, text, tokens)
      super
    end

    def set_data(response)

      webmentions = {}

      if response and response['links']
        webmentions = process_webmentions(response['links'])
      end

      if webmentions
        body = webmentions.force_encoding('UTF-8')
      end
      
      "<div class=\"webmentions\">#{body}</div>"
    end
    
    def parse_links(links)
      
      # load from the cache
      cache_file = File.join(WEBMENTION_CACHE_DIR, 'webmentions_received.yml')
      if File.exists?(cache_file)
        cached_webmentions = open(cache_file) { |f| YAML.load(f) }
      else
        cached_webmentions = {}
      end
      
      # puts links.inspect
      links.reverse_each { |link|
        
        id = link['id']
        url = link['data']['url'] || link["source"]
          
        # Tweets get handled differently
        is_tweet = false
        if url.include? 'twitter.com/'
          is_tweet = true
          # Unique tweets gets unique IDs
          if ! url.include? '#favorited-by'
            id = URI(link['data']['url']).path.split('/').last
          end
        end
        
        # Google Plus gets handled differently
        is_gplus = false
        if url.include? '/googleplus/'
          is_gplus = true
        end
        
        # No ID
        if ! id
          time = Time.now();
          id = time.strftime('%s')
        end

        if key_exists cached_webmentions, id
          # puts "found #{id}, using the cached one…"
          next
        end

        # Get the mentioned URI, stripping fragments and query strings
        target = URI::parse( link['target'] )
        target.fragment = target.query = nil
        target = target.to_s
        
        pubdate = link['data']['published_ts']
        if pubdate
          pubdate = Time.at(pubdate)
        elsif link['verified_date']
          pubdate = Time.parse(link['verified_date'])
        end
        the_date = pubdate.strftime('%s')

        # Make sure we have the target
        if ! cached_webmentions[target]
          cached_webmentions[target] = {}
        end

        # Make sure we have the date
        if ! cached_webmentions[target][the_date]
          cached_webmentions[target][the_date] = {}
        end

        # Make sure we have the webmention
        # puts "#{target} - #{the_date} - #{id}"
        if ! cached_webmentions[target][the_date][id]
          
          webmention = ''
          webmention_classes = 'webmention'
          
          ####
          # Authorship
          ####
          author = link['data']['author']
          author_block = ''
          
          if author

            # puts author
            a_name = author['name']
            a_url = author['url']
            a_photo = author['photo']

            if a_photo
              if is_working_uri( a_photo )
                author_block << "<img class=\"webmention__author__photo u-photo\" src=\"#{a_photo}\" alt=\"\" title=\"#{a_name}\">"
              else
                webmention_classes << ' webmention--no-photo'
              end
            end

            name_block = "<b class=\"p-name\">#{a_name}</b>"
            author_block << name_block

            if a_url
              author_block = "<a class=\"u-url\" href=\"#{a_url}\">#{author_block}</a>"
            end

            author_block = "<div class=\"webmention__author p-author h-card\">#{author_block}</div>"
          
          elsif
            webmention_classes << ' webmention--no-author'
          end

          ####
          # Content
          ####
          title = link['data']['name']
          content = link['data']['content']
          type = link['activity']['type']
          
          # fix bad webmentions
          if ! type
            # Trap Google Plus from Bridgy
            if is_gplus
              if url.include? '/like/'
                type = 'like'
              elsif url.include? '/repost/'
                type = 'repost'
              elsif url.include? '/comment/'
                type = 'reply'
              else
                type = 'link'
              end
            # Default
            else
              type = 'post'
            end
          end
          # more than likely the content was pushed into the post name
          if title and title.length > 200
            title = false
          end

          # Google Plus masked by Bridgy
          if is_gplus and url.include? 'brid-gy'
            # sometimes links go away
            if is_working_uri( url )
              # Now get the content
              html_source = get_uri_source(url)
              
              if ! html_source.valid_encoding?
                # puts "invalid encoding\r\n"
                html_source = html_source.encode('UTF-16be', :invalid=>:replace, :replace=>"?").encode('UTF-8')
              end
              
              matches = /class="u-url" href=".+">(https:.+)</.match( html_source )
              if matches
                url = matches[1].strip
              end
            else
              url = false
            end
          end

          # Posts (but not tweeted links)
          link_title = false
          if type == 'post' or ( type == 'link' and ! is_tweet and ! is_gplus )

            # No title, look it up
            if ! title and url
              url = link['source']
              
              # ping it first
              if ! is_working_uri( url )
                puts "#{url} is not returning a 200 HTTP status, skipping it"
                next
              end
              
              # Now get the content
              # print "checking #{url}\r\n"
              html_source = get_uri_source(url)
              # print "#{html_source}\r\n"
              
              if ! html_source.valid_encoding?
                html_source = html_source.encode('UTF-16be', :invalid=>:replace, :replace=>"?").encode('UTF-8')
              end

              matches = /<title>(.*)<\/title>/.match( html_source )
              if matches
                title = matches[1].strip
              else
                matches = /<h1>(.*)<\/h1>/.match( html_source )
                if matches
                  title = matches[1].strip
                else
                  title = 'No title available'
                end
              end
              
              title = title.gsub(%r{</?[^>]+?>}, '')
            end

            link_title = title
          
          # Likes & Shares
          elsif type == 'like' or type == 'repost'
            # new twitter faves are doing something weird
            if type == 'like' and is_tweet
              link_title = "#{a_name} favorited this."
            elsif type == 'repost' and is_tweet
              link_title = "#{a_name} retweeted this."
            else
              link_title = title
            end
            webmention_classes << ' webmention--author-starts'
          end

          # Published info
          pubdate_iso = pubdate.strftime('%FT%T%:z')
          pubdate_formatted = pubdate.strftime('%-d %B %Y')
          published_block = "<time class=\"webmention__pubdate dt-published\" datetime=\"#{pubdate_iso}\">#{pubdate_formatted}</time>"

          meta_block = ''
          if published_block
            meta_block << published_block
          end
          if ! link_title
            if published_block and url
              meta_block << ' | '
            end
            if url
              meta_block << "<a class=\"webmention__source u-url\" href=\"#{url}\">Permalink</a>"
            end
          end
          if meta_block
            meta_block = "<div class=\"webmention__meta\">#{meta_block}</div>"
          end

          if a_name and ( ( title and title.start_with?(a_name) ) or ( content and content.start_with?(a_name) ) )
            webmention_classes << ' webmention--author-starts'
          end

          # Build the content block
          content_block = ''
          if link_title

            link_title = link_title.sub 'reposts', 'reposted'
            
            webmention_classes << ' webmention--title-only'

            if url
              content_block = "<a href=\"#{url}\">#{link_title}</a>"
            else
              content_block = link_title
            end
            
            # build the block
            content_block = " <div class=\"webmention__title p-name\">#{content_block}</div>"
            
          else
            
            webmention_classes << ' webmention--content-only'
            
            content = @converter.convert("#{content}")
            if !content.start_with?('<p')
              content = content.sub(/^<[^>]+>/, '<p>').sub(/<\/[^>]+>$/, '</p>')
            end
            
            content_block << "<div class=\"webmention__content p-content\">#{content}</div>"

          end

          # meta
          content_block << meta_block
            
          # put it together
          webmention << "<li id=\"webmention-#{id}\" class=\"webmentions__item\">"
          webmention << "<article class=\"h-cite #{webmention_classes}\">"
          
          webmention << author_block
          webmention << content_block
          webmention << '</article></li>'

          cached_webmentions[target][the_date][id] = webmention
          
        end
        
      }
      
      # store it all back in the cache
      File.open(cache_file, 'w') { |f| YAML.dump(cached_webmentions, f) }
      
      all_webmentions = {}

      # merge & organize by day
      # puts @targets.inspect
      if @targets.length
        @targets.each do |target|
          # puts target
          if cached_webmentions[target]
            # puts cached_webmentions[target].inspect
            cached_webmentions[target].each do |day, webmentions|
              if ! all_webmentions[day]
                all_webmentions[day] = {}
              end
              webmentions.each do |key, webmention|
                if ! all_webmentions[day][key]
                  all_webmentions[day][key] = webmention
                end
              end
            end
          end
        end
      end

      #puts all_webmentions

      # build the html
      lis = ''
      if all_webmentions.length
        all_webmentions.sort.each do |day, webmentions|
          webmentions.each do |key, webmention|
            lis << webmention
          end
        end
      end

      if lis != ''
        "<ol class=\"webmentions__list\">#{lis}</ol>"
      end
    end

  end

end

Liquid::Template.register_tag('webmentions', Jekyll::WebmentionsTag)