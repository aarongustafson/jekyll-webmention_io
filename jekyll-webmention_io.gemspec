# frozen_string_literal: true

# Test: bundle exec cucumber
# Push: gem bump jekyll-webmention_io -v patch -p -t -r

require File.expand_path('lib/jekyll/webmention_io/version', __dir__)

Gem::Specification.new do |s|
  s.name          = 'jekyll-webmention_io'
  s.version       = Jekyll::WebmentionIO::VERSION
  s.license       = 'MIT'
  s.authors       = ['Aaron Gustafson']
  s.email         = ['aaron@easy-designs.net']
  s.homepage      = 'https://github.com/aarongustafson/jekyll-webmention_io'

  s.summary       = 'A Jekyll plugin for sending & receiving webmentions via Webmention.io.'
  s.description   = <<~DESCRIPTION
    This Gem includes a suite of tools for managing webmentions in Jekyll:

    * Tags
      * Count of webmentions (filterable)
      * All webmentions (filterable)
      * Bookmarks
      * Likes
      * Links
      * Posts
      * Replies
      * Reposts
      * RSVPs
      * Contents for the `head` of your pages
      * JavaScript enhancements
    * Commands - Send webmentions you’ve made
    * Generators - Collect webmentions from Webmention.io and gather sites you’ve mentioned
  DESCRIPTION

  s.required_ruby_version = '>= 2.7.0'

  s.platform      = Gem::Platform::RUBY
  s.files         = `git ls-files app lib`.split("\n")
  s.require_paths = ['lib']

  s.add_dependency 'activesupport', '~> 7.0', '>= 7.0.4.3'
  s.add_dependency 'htmlbeautifier', '~> 1.1'
  s.add_dependency 'jekyll', '>= 3.2.0', '< 5.0'
  s.add_dependency 'json', '~> 2.0'
  s.add_dependency 'jsonpath', '~> 1.0.1'
  s.add_dependency 'openssl', '>= 2.0', '< 4.0'
  s.add_dependency 'uglifier', '~> 4.1'
  s.add_dependency 'webmention', '~> 7.0'

  s.add_development_dependency 'capybara', '~> 3.35'
  s.add_development_dependency 'cucumber', '~> 3.1'
  s.add_development_dependency 'cuprite', '~> 0.14'
  s.add_development_dependency 'ferrum', '>= 0.14'
  s.add_development_dependency 'html-proofer', '~> 3.6'
  s.add_development_dependency 'kramdown-parser-gfm', '~> 1.1'
  s.add_development_dependency 'nokogiri', '~> 1.18'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.5'
  s.add_development_dependency 'rubocop', '~> 1.81'
  s.add_development_dependency 'timecop', '~> 0.9'
end
