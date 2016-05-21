#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_head_tags %}
#    {% webmention_js_tag %}
#    {% webmention_redirected_from PAGE, TAGS, TO, READ %}
#    {% webmentions URL %}
#    {% webmention_count URL %}
#
#  Notify any mentioned sites that are webmention enabled:
#
#    jekyll webmention

def config_err(key)
  Jekyll.logger.warn "jekyll-webmention-io:", "Required _config.yml key not defined: #{key}"
  Jekyll.logger.warn "jekyll-webmention-io:", "Exiting.."
  exit 1
end

# TODO: Find a less hacky way of accessing the config here
WEBMENTION_JEKYLL_CONFIG = Jekyll.configuration({})

config_err('jekyll-webmention-io') unless WEBMENTION_JEKYLL_CONFIG.has_key?('jekyll-webmention-io')
config_err('jekyll-webmention-io.domain') unless WEBMENTION_JEKYLL_CONFIG['jekyll-webmention-io'].has_key?('domain')

WEBMENTION_CONFIG = WEBMENTION_JEKYLL_CONFIG['jekyll-webmention-io']

WEBMENTION_GEM_BASE_DIR = File.expand_path('../../', __FILE__)
WEBMENTION_JEKYLL_BASE_DIR = Dir.pwd

WEBMENTION_CACHE_DIR = File.expand_path(WEBMENTION_CONFIG['cache'] || ".jekyll-webmention-io", Dir.pwd)
FileUtils.mkdir_p(WEBMENTION_CACHE_DIR)

require "jekyll-webmention-io/version"
require "jekyll-webmention-io/webmentions"

require "jekyll-webmention-io/webmention_command"
require "jekyll-webmention-io/webmentions_tag"
require "jekyll-webmention-io/webmention_count_tag"
require "jekyll-webmention-io/webmention_generator"
require "jekyll-webmention-io/webmention_head_tags"
require "jekyll-webmention-io/webmention_js_generator"
require "jekyll-webmention-io/webmention_js_tag"
require "jekyll-webmention-io/webmention_redirected_from_tag"
