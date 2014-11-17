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

module Jekyll
  
  class Webmentions < Liquid::Tag
    
    def initialize(tagName, text, tokens)
      super
      @text = text
      @api_endpoint = ""
    end
    
    def render(context)
      args = @text.split(/\s+/).map(&:strip)
      api_params = {'target' => args.shift}
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
      api_uri = URI.parse(@api_endpoint + "?#{url_params_for(api_params)}")
      response = Net::HTTP.get(api_uri.host, api_uri.request_uri)
      JSON.parse(response)
    end

  end
  
  class WebmentionsTag < Webmentions
  
    def initialize(tagName, text, tokens)
      super
      @api_endpoint = "http://webmention.io/api/mentions"
    end

    def html_output_for(response)
      body = "<p class=\"webmentions__not-found\">No webmentions were found</p>"
      
      if response['links']
        body = parse_links(response['links'])
      end
      
      "<div class=\"webmentions\">#{body}</div>"
    end
    
    def parse_links(links)
      lis = ""
      
      links.each { |link|
        
        title = link["data"]["name"]
        content = link["data"]["content"]
        url = link["data"]["url"]
        link_title = title || url
        
        author_block = ""
        if author = link["data"]["author"]

          a_name = author["name"]
          a_url = author["url"]
          a_photo = author["photo"]
        
          if a_photo
            author_block << "<img class=\"webmention__author__photo photo\" src=\"#{a_photo}\" alt=\"\">"
          end
        
          author_block << "#{a_name}"
        
          if a_url
            author_block = "<a href=\"#{a_url}\">#{author_block}</a>"
          end

          author_block = "<div class=\"webmention__author\">#{author_block}</div>"
        end
        
        published_block = ""
        pubdate = link["data"]["published"]
        if pubdate
          pubdate_formatted = Time.at(link["data"]["published_ts"]).strftime("%-d %B %Y")
          published_block = "<time class=\"webmention__pubdate\" datetime=\"#{pubdate}\">#{pubdate_formatted}</time>"
        end
                
        if title and content and title == content
          title = false
        end
        
        if title
          
          lis << "<li class=\"webmentions__item\"><article class=\"webmention webmention--title-only\">"
          lis << author_block
          lis << "<div class=\"webmention__title\"><a href=\"#{url}\">#{link_title}</a></div>"
          lis << "<div class=\"webmention__meta\">#{published_block}</div>"
          lis << "</article></li>"
          
        elsif content
          content = @converter.convert("#{content}")
          
          lis << "<li class=\"webmentions__item\"><article class=\"webmention webmention--content-only\">"
          lis << author_block
          lis << "<div class=\"webmention__meta\">#{published_block} | <a class=\"webmention__source\" href=\"#{url}\">Permalink</a></div>"
          lis << "<div class=\"webmention__content\">#{content}</div>"
          lis << "</article></li>"
        end
        
      }

      "<ol class=\"webmentions__list\">#{lis}</ol>"
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
  
end

Liquid::Template.register_tag('webmentions', Jekyll::WebmentionsTag)
Liquid::Template.register_tag('webmention_count', Jekyll::WebmentionCountTag)