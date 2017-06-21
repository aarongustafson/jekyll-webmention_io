#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  Base webmention tag
#

require 'htmlbeautifier'

module Jekyll
  using StringInflection
  class WebmentionTag < Liquid::Tag
    
    def initialize(tagName, text, tokens)
      super
      cache_file = WebmentionIO.get_cache_file_path 'incoming'
      if File.exists?(cache_file)
        @cached_webmentions = open(cache_file) { |f| YAML.load(f) }
      else
        @cached_webmentions = {}
      end
    end

    def lookup(context, name)
      lookup = context
      name.split(".").each do |value|
        lookup = lookup[value]
      end
      lookup
    end
    
    def set_template( template )
      supported_templates = WebmentionIO.types + ['count', 'webmentions']
      
      WebmentionIO.log 'error', "#{template} is not supported" if ! supported_templates.include? template

      if WebmentionIO.config.has_key? 'templates' and WebmentionIO.config['templates'].has_key? template
        # WebmentionIO.log 'info', "Using custom #{template} template"
        template_file = WebmentionIO.config['templates'][template]
      else
        # WebmentionIO.log 'info', "Using default #{template} template"
        template_file = File.join(File.dirname(File.expand_path(__FILE__)), "../../../templates/#{template}.html")
      end

      # WebmentionIO.log 'info', "Template file: #{template_file}"
      handler = File.open(template_file, 'rb')
      @template = handler.read
      # WebmentionIO.log 'info', "template: #{@template}"
    end

    def set_data(data)
      @data = { 'webmentions' => data }
    end

    def extract_type( type, webmentions )
      # WebmentionIO.log 'info', "Looking for #{type}"
      keep = {}
      if ! WebmentionIO.types.include? type
        WebmentionIO.log 'warn', "#{type} are not extractable"
      else
        type = type.to_singular
        # WebmentionIO.log 'info', "Searching #{webmentions.length} webmentions for type==#{type}"
        if webmentions.is_a? Hash
          webmentions = webmentions.values
        end
        webmentions.each do |webmention|
          keep[webmention['id']] = webmention if webmention['type'] == type
        end
      end
      keep
    end

    def sort_webmentions( webmentions )
      return webmentions.sort_by { |webmention| webmention['pubdate'].to_i }
    end

    def render(context)
      output = super
      
      # Get the URI
      args = @text.split(/\s+/).map(&:strip)
      uri = args.shift
      uri = lookup(context, uri)

      if @cached_webmentions.has_key? uri
        all_webmentions =  @cached_webmentions[uri].clone
        # WebmentionIO.log 'info', "#{all_webmentions.length} total webmentions for #{uri}"
        if args.length > 0
          # WebmentionIO.log 'info', "Requesting only #{args.inspect}"
          webmentions = {}
          args.each do |type|
            extracted = extract_type( type, all_webmentions )
            # WebmentionIO.log 'info', "Merging in #{extracted.length} #{type}"
            webmentions = webmentions.merge( extracted )
          end
        else
          # WebmentionIO.log 'info', 'Grabbing all webmentions'
          webmentions = all_webmentions
        end

        if webmentions.is_a? Hash
          webmentions = webmentions.values
        end

        webmentions = sort_webmentions( webmentions )
        
        set_data( webmentions )
      end
      
      args = nil

      if @template and @data
        # WebmentionIO.log 'info', "Preparing to render\n\n#{@data.inspect}\n\ninto\n\n#{@template}"
        template = Liquid::Template.parse(@template, :error_mode => :strict)
        html = template.render(@data, { strict_variables: true, strict_filters: true })
        template.errors.each do |error|
          WebmentionIO.log 'error', error
        end
        # Clean up the output
        HtmlBeautifier.beautify html.each_line.reject{|x| x.strip == ""}.join
      else
        if ! @template
          WebmentionIO.log 'warn', "#{self.class} No template provided"
        end
        if ! @data
          WebmentionIO.log 'warn', "#{self.class} No data provided"
        end
        ""
      end
    end
  end
end