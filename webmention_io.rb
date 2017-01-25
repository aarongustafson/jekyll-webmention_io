#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmentions URL %}
#    {% webmention_count URL %}
#   
require 'json'
require 'net/http'
require 'uri'
require 'openssl'

WEBMENTION_CACHE_DIR = File.expand_path('../../.cache', __FILE__)
FileUtils.mkdir_p(WEBMENTION_CACHE_DIR)

module Jekyll
  
  class Webmentions < Liquid::Tag
    
    def initialize(tagName, text, tokens)
      super
      @text = text
      @api_endpoint = ''
      @api_suffix = ''
      @targets = []
    end
    
    def render(context)
      output = super
      
      args = @text.split(/\s+/).map(&:strip)
      args.each do |url|
        target = lookup(context, url)
        @targets.push(target)
        # For legacy (non www) URIs
        legacy = target.sub 'www.', ''
        @targets.push(legacy)
        # For legacy (non https) URIs
        legacy = target.sub 'https://', 'http://'
        @targets.push(legacy)
        # Combined
        legacy = legacy.sub 'www.', ''
        @targets.push(legacy)
      end
      
      api_params = @targets.collect { |v| "target[]=#{v}" }.join('&')
      api_params << @api_suffix

      response = get_response(api_params)

      site = context.registers[:site]

      # post Jekyll commit 0c0aea3
      # https://github.com/jekyll/jekyll/commit/0c0aea3ad7d2605325d420a23d21729c5cf7cf88
      if defined? site.find_converter_instance
        @converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
      # Prior to Jekyll commit 0c0aea3
      else
        @converter = site.getConverterImpl(::Jekyll::Converters::Markdown)
      end

      html_output_for(response)
    end

    def html_output_for(response)
      ""
    end
    
    def url_params_for(api_params)
      api_params.keys.sort.map do |k|
        "#{CGI::escape(k)}=#{CGI::escape(api_params[k])}"
      end.join('&')
    end

    def get_response(api_params)
      source = get_uri_source(@api_endpoint + "?#{api_params}")
      if source
        # print source
        JSON.parse(source)
      else
        ""
      end
    end
    
    def lookup(context, name)
      lookup = context

      name.split(".").each do |value|
        lookup = lookup[value]
      end

      lookup
    end

    def key_exists(hash, test_key)
      if hash.is_a? Hash 
        hash.each do |key, value|
          if test_key == key
            return true
          # nest
          elsif value.is_a? Hash
            if key_exists value, test_key
              return true
            end
          end
        end
      end
      return false
    end
    
    def is_working_uri(uri, redirect_limit = 10, original_uri = false)
      # puts "checking URI #{uri}"
      original_uri = original_uri || uri
      if redirect_limit > 0
        uri = URI.parse(URI.encode(uri))
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10
        if uri.scheme == 'https'
          http.use_ssl = true
          http.ssl_version = :TLSv1
          http.ciphers = "ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:-LOW"
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        begin 
          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)
          case response
            when Net::HTTPSuccess then
              return true
            when Net::HTTPRedirection then
              # puts "Location redirect to #{response['location']}"
              redirect_to = URI.parse(URI.encode(response['location']))
              redirect_to = redirect_to.relative? ? "#{uri.scheme}://#{uri.host}" + redirect_to.to_s : redirect_to.to_s
              # puts "redirecting to #{redirect_to}"
              return is_working_uri(redirect_to, redirect_limit - 1, original_uri)
            else
              return false
          end
        rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
          warn "Got an error checking #{original_uri}: #{e}"
          return false
        rescue Exception => e
          warn "Got an error: #{e}"
        end
      else
        if original_uri
          warn "too many redirects for #{original_uri}"
        end
        return false
      end
    end
    
    def get_uri_source(uri, redirect_limit = 10, original_uri = false)
      # puts "Getting the source of #{uri}"
      original_uri = original_uri || uri
      if redirect_limit > 0
        uri = URI.parse(URI.encode(uri))
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10
        if uri.scheme == 'https'
          http.use_ssl = true
          http.ssl_version = :TLSv1
          http.ciphers = "ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:-LOW"
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        begin
          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)
        rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
          warn "Got an error checking #{original_uri}: #{e}"
          return false
        end
        case response
          when Net::HTTPSuccess then
            return response.body.force_encoding('UTF-8')
          when Net::HTTPRedirection then
            # puts "Location redirect to #{response['location']}"
            redirect_to = URI.parse(URI.encode(response['location']))
            redirect_to = redirect_to.relative? ? "#{uri.scheme}://#{uri.host}" + redirect_to.to_s : redirect_to.to_s
            # puts "redirecting to #{redirect_to}"
            return get_uri_source(redirect_to, redirect_limit - 1, original_uri)
          else
            return false
        end
      else
        if original_uri
          warn "too many redirects for #{original_uri}"
        end
        return false
      end
    end

  end
  
  class WebmentionsTag < Webmentions
  
    def initialize(tagName, text, tokens)
      super
      @api_endpoint = 'http://webmention.io/api/mentions'
      # add an arbitrarily high perPage to trump pagination
      @api_suffix = '&perPage=9999'
    end

    def html_output_for(response)
      body = '<p class="webmentions__not-found">No webmentions were found</p>'
      
      if response and response['links']
        webmentions = parse_links(response['links'])
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

  class WebmentionCountTag < Webmentions
    
    def initialize(tagName, text, tokens)
      super
      @api_endpoint = 'http://webmention.io/api/count'
    end

    def html_output_for(response)
      count = response['count'] || '0'
      "<span class=\"webmention-count\">#{count}</span>"
    end
    
  end
  
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

Liquid::Template.register_tag('webmentions', Jekyll::WebmentionsTag)
Liquid::Template.register_tag('webmention_count', Jekyll::WebmentionCountTag)