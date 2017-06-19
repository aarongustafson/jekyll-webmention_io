# encoding: utf-8

$:.unshift File.expand_path('../lib', __FILE__)
require 'lib/jekyll/webmention_io/version'

Gem::Specification.new do |s|
  s.name          = "Webmention.io Support for Jekyll"
  s.version       = WebmentionIO::VERSION
  s.authors       = ["Aaron Gustafson"]
  s.email         = ["aaron@easy-designs.net"]
  s.homepage      = "https://github.com/aarongustafson/jekyll-webmention_io"
  s.summary       = "A Jekyll Plugin for rendering Webmentions via Webmention.io"
  s.description   = "This plugin makes it possible to load webmentions from Webmention.io into your Jekyll and Octopress projects."

  s.platform      = Gem::Platform::RUBY

  s.files         = Dir.glob("lib/**/*") +
                    Dir.glob("assets/*") + 
                    Dir.glob("templates/*")

  s.require_paths << 'templates'
  s.require_paths << 'assets'
end
