#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmentions URL %}
#    {% webmention_count URL %}
#   
require "jekyll-webmention_io/version"
require "jekyll-webmention_io/webmentions"
require "jekyll-webmention_io/webmentions_tag"
require "jekyll-webmention_io/webmention_count_tag"
require "jekyll-webmention_io/webmention_generator"

WEBMENTION_CACHE_DIR = File.expand_path('../../.cache', __FILE__)
FileUtils.mkdir_p(WEBMENTION_CACHE_DIR)

# module Jekyll
#   module WebmentionIo
#     # Your code goes here...
#   end
# end
