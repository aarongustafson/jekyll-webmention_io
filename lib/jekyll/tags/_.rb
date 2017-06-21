#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  Base webmention tag
#   
module Jekyll
  using StringInflection
  class WebmentionTag < Liquid::Tag
    
    def initialize(tagName, text, tokens)
      super
      @types = ['likes','posts','replies','reposts']

      @text = text
      @template = false
      @data = false
      
      @webmention_io = WebmentionIO.new

      cache_file = @webmention_io.get_cache_file_path 'incoming'
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
      supported_templates = @types + ['count', 'webmentions']
      
      @webmention_io.log 'error', "#{template} is not supported" if ! supported_templates.include? template

      if @webmention_io.config.has_key? 'templates' and @webmention_io.config['templates'].has_key? template
        template_file = @webmention_io.config['templates'][template]
      else
        template_file = File.join(File.dirname(File.expand_path(__FILE__)), "../../../templates/#{template}.html")
      end

      handler = File.open(template_file, 'rb')
      @template = handler.read
    end
    
    def set_data(data)
      @data = { 'webmentions' => data }
    end

    def extract_type( type, webmentions )
      if ! @types.include? type
        @webmention_io.log 'warn', "#{type} are not extractable"
        return {}
      end
      type = type.to_singular
      return webmentions.keep_if { |webmention| webmention['type'] == type }
    end

    def get_webmentions_as_array( hash )
      return hash.values
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

      # puts "#{@cached_webmentions.length} URIs mentioned"
      if @cached_webmentions.has_key? uri
        # puts "#{@cached_webmentions[uri].length} webmentions for #{uri}"
        if args.length > 0
          # puts 'Multiple types requested'
          webmentions = {}
          args.each do |type|
            # puts "Merging in #{type}"
            extracted = extract_type( type, @cached_webmentions[uri] )
            # puts extracted.inspect
            webmentions.merge( extracted )
          end          
        else
          # puts 'Grabbing ’em all'
          webmentions = @cached_webmentions[uri]
        end

        webmentions = get_webmentions_as_array( webmentions )
        
        webmentions = sort_webmentions( webmentions )
        
        set_data( webmentions )
      end
      
      if @template and @data
        template = Liquid::Template.parse(@template, :error_mode => :strict)
        template.render(@data, { strict_variables: true, strict_filters: true })
        template.errors.each do |error|
          @webmention_io.log 'error', error
        end        
      else
        if ! @template
          @webmention_io.log 'warn', "#{self.class} No template provided"
        end
        if ! @data
          @webmention_io.log 'warn', "#{self.class} No data provided"
        end
        ""
      end
    end
  end
end