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

WEBMENTION_CACHE_DIR = File.expand_path('../../.webmention-cache', __FILE__)
FileUtils.mkdir_p(WEBMENTION_CACHE_DIR)

module Jekyll
  
  class Webmentions < Liquid::Tag
    
    def initialize(tagName, text, tokens)
      super
      @text = text
      @api_endpoint = ""
    end
    
    def render(context)
      output = super
      
      targets = []
      
      args = @text.split(/\s+/).map(&:strip)
      args.each do |url|
        target = lookup(context, url)
        targets.push(target)
      end
      
      api_params = targets.collect { |v| "target[]=#{v}" }.join("&")
      response = get_response(api_params)

      site = context.registers[:site]
      @converter = site.getConverterImpl(::Jekyll::Converters::Markdown)

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
      api_uri = URI.parse(@api_endpoint + "?#{api_params}")
      response = Net::HTTP.get(api_uri.host, api_uri.request_uri)
      if response
        JSON.parse(response)
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

  end
  
  class WebmentionsTag < Webmentions
  
    def initialize(tagName, text, tokens)
      super
      @api_endpoint = "http://webmention.io/api/mentions"
    end

    def html_output_for(response)
      body = "<p class=\"webmentions__not-found\">No webmentions were found</p>"
      
      if response and response['links']
        webmentions = parse_links(response['links'])
      end

      if webmentions
        body = webmentions
      end
      
      "<div class=\"webmentions\">#{body}</div>"
    end
    
    def parse_links(links)
      
      # load from the cache
      cache_file = File.join(WEBMENTION_CACHE_DIR, "recieved_webmentions.yml")
      if File.exists?(cache_file)
        cached_webmentions = open(cache_file) { |f| YAML.load(f) }
      else
        cached_webmentions = {}
      end
      
      lis = ""

      links.reverse_each { |link|
        
        id = link["id"]
        
        if ! cached_webmentions[id]
          
          webmention = ""

          title = link["data"]["name"]
          content = link["data"]["content"]
          url = link["data"]["url"]

          if ! ( title and content and url )
            url = link["source"]
            
            status = `curl -s -I -L -o /dev/null -w "%{http_code}" --location "#{url}"`
            next if status != "200"
            
            title = `curl -s --location "#{url}" | grep '<title>'`
            if title
              title = title.gsub(/<\/?title>/i,'').strip
            end
          end

          link_title = title || url

          if title and content and title == content
            title = false
          end

          if ! id
            time = Time.now();
            id = time.strftime("%s")
          end

          author_block = ""
          if author = link["data"]["author"]

            #puts author
            a_name = author["name"]
            a_url = author["url"]
            a_photo = author["photo"]

            if a_photo
              status = `curl -s -I -L -o /dev/null -w "%{http_code}" --location "#{a_photo}"`
              if status == "200"
                author_block << "<img class=\"webmention__author__photo u-photo\" src=\"#{a_photo}\" alt=\"\" title=\"#{a_name}\">"
              end
            end

            name_block = "<b class=\"p-name\">#{a_name}</b>"
            author_block << name_block

            if a_url
              author_block = "<a class=\"u-url\" href=\"#{a_url}\">#{author_block}</a>"
            end

            author_block = "<div class=\"webmention__author p-author h-card\">#{author_block}</div>"
          end

          published_block = ""
          pubdate = link["data"]["published_ts"]
          if pubdate
            pubdate = Time.at(pubdate)
          elsif link["verified_date"]
            pubdate = Time.parse(link["verified_date"])
          end
          if pubdate
            pubdate_iso = pubdate.strftime("%FT%T%:z")
            pubdate_formatted = pubdate.strftime("%-d %B %Y")
            published_block = "<time class=\"webmention__pubdate dt-published\" datetime=\"#{pubdate_iso}\">#{pubdate_formatted}</time>"
          end

          webmention_classes = "webmention"
          if a_name and ( title and title.start_with?(a_name) ) or ( content and content.start_with?(a_name) )
            webmention_classes << ' webmention--author-starts'
          end

          content_block = ""
          if link_title
            webmention_classes << " webmention--title-only"
            if url
              content_block << "<div class=\"webmention__title p-name\"><a href=\"#{url}\">#{link_title}</a></div>"
            else
              content_block << "<div class=\"webmention__title p-name\">#{link_title}</div>"
            end
            if published_block
              content_block << "<div class=\"webmention__meta\">#{published_block}</div>"
            end
          elsif content
            content = @converter.convert("#{content}")
            webmention_classes << " webmention--content-only"
            content_block << "<div class=\"webmention__meta\">"
            if published_block
              content_block << published_block
            end
            if published_block and url
                content_block << " | "
            end
            if url
              content_block << "<a class=\"webmention__source u-url\" href=\"#{url}\">Permalink</a>"
            end
            content_block << "</div>"
            content_block << "<div class=\"webmention__content p-content\">#{content}</div>"
          end

          # put it together
          webmention << "<li id=\"webmention-#{id}\" class=\"webmentions__item\">"
          webmention << "<article class=\"h-cite #{webmention_classes}\">"
          webmention << author_block
          webmention << content_block
          webmention << "</article></li>"

          cached_webmentions[id] = webmention
          
        end
        
        lis << cached_webmentions[id]
        
      }
      
      # store it all back in the cache
      File.open(cache_file, 'w') { |f| YAML.dump(cached_webmentions, f) }
      
      if lis != ""
        "<ol class=\"webmentions__list\">#{lis}</ol>"
      end
    end

  end

  class WebmentionCountTag < Webmentions
    
    def initialize(tagName, text, tokens)
      super
      @api_endpoint = "http://webmention.io/api/count"
    end

    def html_output_for(response)
      count = response['count'] || "0"
      "<span class=\"webmention-count\">#{count}</span>"
    end
    
  end
  
  class WebmentionGenerator < Generator
    safe true
    priority :low
    
    def generate(site)
      webmentions = {}
      if defined?(WEBMENTION_CACHE_DIR)
        cache_file = File.join(WEBMENTION_CACHE_DIR, "webmentions.yml")
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