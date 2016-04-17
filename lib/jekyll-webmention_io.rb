#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_head_tags %}
#    {% webmention_js_tag %}
#    {% webmentions URL %}
#    {% webmention_count URL %}
#   

def config_err(key)
  Jekyll.logger.warn "jekyll-webmention-io:", "Required _config.yml key not defined: #{key}"
  Jekyll.logger.warn "jekyll-webmention-io:", "Exiting.."
  exit 1
end

WEBMENTION_JEKYLL_CONFIG = Jekyll.configuration({})

config_err('jekyll-webmention-io') unless WEBMENTION_JEKYLL_CONFIG.has_key?('jekyll-webmention-io')
config_err('jekyll-webmention-io.domain') unless WEBMENTION_JEKYLL_CONFIG['jekyll-webmention-io'].has_key?('domain')

WEBMENTION_CONFIG = WEBMENTION_JEKYLL_CONFIG['jekyll-webmention-io']

WEBMENTION_GEM_BASE_DIR = File.expand_path('../../', __FILE__)
WEBMENTION_JEKYLL_BASE_DIR = Dir.pwd

WEBMENTION_CACHE_DIR = File.expand_path(WEBMENTION_CONFIG['cache'] || ".jekyll-webmention-io", Dir.pwd)
FileUtils.mkdir_p(WEBMENTION_CACHE_DIR)

require "jekyll-webmention_io/version"
require "jekyll-webmention_io/webmentions"
require "jekyll-webmention_io/webmentions_tag"
require "jekyll-webmention_io/webmention_count_tag"
require "jekyll-webmention_io/webmention_generator"
require "jekyll-webmention_io/webmention_head_tags"
require "jekyll-webmention_io/webmention_js_generator"
require "jekyll-webmention_io/webmention_js_tag"

# module Jekyll
#   module WebmentionIo
#     # Your code goes here...
#   end
# end
