# encoding: utf-8

$:.unshift File.expand_path('../lib', __FILE__)
require 'jekyll/webmention_io/version'

Gem::Specification.new do |s|
  s.name          = 'jekyll-webmention_io'
  s.version       = WebmentionIO::VERSION
  s.license       = 'MIT'
  s.authors       = ['Aaron Gustafson']
  s.email         = ['aaron@easy-designs.net']
  s.homepage      = 'https://github.com/aarongustafson/jekyll-webmention_io'
  s.has_rdoc      = false

  s.summary       = 'A Jekyll plugin for sending & receiving webmentions via Webmention.io.'
  s.description   = <<-EOF
This Gem includes a full suite of tools for managing webmentions in Jekyll:

* Tags - render webmention info into your templates:
** All webmentions
** Count of webmentions
** Likes
** Replies
** Reposts
* Commands - Send webmentions you’ve made
* Generators - Collect webmentions from Webmention.io and gather sites you’ve mentioned
EOF
  
  s.platform      = Gem::Platform::RUBY

  s.files         = Dir.glob('lib/**/*') +
                    Dir.glob('assets/*') + 
                    Dir.glob('templates/*')

  s.require_paths = ['.']

  s.add_runtime_dependency 'string_inflection', '~> 0.1'
  s.add_runtime_dependency 'htmlbeautifier', '~> 1.1'
  s.add_runtime_dependency "jekyll", ">= 3.0", "< 4.0"

  s.add_development_dependency "bundler", "~> 1.14"
  s.add_development_dependency "rake", "~> 12.0"
  s.add_development_dependency "rubocop", "~> 0.48"
end
