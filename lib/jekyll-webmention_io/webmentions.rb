#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

require 'json'
require 'net/http'
require 'uri'

module Jekyll
  module WebmentionIo
    class Webmentions < Liquid::Tag
    
      def initialize(tagName, text, tokens)
        super
        @text = text
        @api_endpoint = ''
        @api_suffix = ''
      end
      
      def render(context)
        output = super
        
        targets = []
        
        args = @text.split(/\s+/).map(&:strip)
        args.each do |url|
          target = lookup(context, url)
          targets.push(target)
          # For legacy (non www) URIs
          legacy = target.sub 'www.', ''
          targets.push(legacy)
        end
        
        api_params = targets.collect { |v| "target[]=#{v}" }.join('&')
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
        api_uri = URI.parse(@api_endpoint + "?#{api_params}")
        # print api_uri
        # print "\r\n"
        response = Net::HTTP.get(api_uri.host, api_uri.request_uri)
        if response
          # print response
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
    
  end
end
