$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'jekyll'
require 'jekyll-webmention_io'
require 'html-proofer'
require 'json'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ENV['JEKYLL_LOG_LEVEL'] = 'error'
