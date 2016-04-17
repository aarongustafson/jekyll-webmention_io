#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmention_head_tags %}
#    {% webmentions URL %}
#    {% webmention_count URL %}
#   
require "jekyll-webmention_io/version"
require "jekyll-webmention_io/webmentions"
require "jekyll-webmention_io/webmentions_tag"
require "jekyll-webmention_io/webmention_count_tag"
require "jekyll-webmention_io/webmention_generator"
require "jekyll-webmention_io/webmention_header_tag"
require "jekyll-webmention_io/webmention_js_generator"

WEBMENTION_GEM_BASE_DIR = File.expand_path('../../', __FILE__)
WEBMENTION_JEKYLL_BASE_DIR = Dir.pwd

WEBMENTION_CONFIG = Jekyll.configuration({})['jekyll-webmention-io']

WEBMENTION_CACHE_DIR = File.expand_path(WEBMENTION_CONFIG['cache'] || ".jekyll-webmention-io", Dir.pwd)
FileUtils.mkdir_p(WEBMENTION_CACHE_DIR)

# module Jekyll
#   module WebmentionIo
#     # Your code goes here...
#   end
# end