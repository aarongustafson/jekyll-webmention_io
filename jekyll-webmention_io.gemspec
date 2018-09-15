# encoding: utf-8
# gem bump jekyll-webmention_io -v patch -p -t -r

require File.expand_path("lib/jekyll/webmention_io/version", __dir__)

Gem::Specification.new do |s|
  s.name          = "jekyll-webmention_io"
  s.version       = Jekyll::WebmentionIO::VERSION
  s.license       = "MIT"
  s.authors       = ["Aaron Gustafson"]
  s.email         = ["aaron@easy-designs.net"]
  s.homepage      = "https://github.com/aarongustafson/jekyll-webmention_io"
  s.has_rdoc      = false

  s.summary       = "A Jekyll plugin for sending & receiving webmentions via Webmention.io."
  s.description   = <<-EOF
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
EOF

  s.platform      = Gem::Platform::RUBY
  s.files         = `git ls-files app lib`.split("\n")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "jekyll", ">= 2.0", "< 4.0"
  s.add_runtime_dependency "json", "~> 2.0"
  s.add_runtime_dependency "http", "~> 2.0"
  s.add_runtime_dependency "openssl", "~> 2.0"
  s.add_runtime_dependency "string_inflection", "~> 0.1"
  s.add_runtime_dependency "htmlbeautifier", "~> 1.1"
  s.add_runtime_dependency "uglifier", "~> 4.1"
  s.add_runtime_dependency "webmention", "~> 0.1.6"

  s.add_development_dependency "bundler", "~> 1.14"
  s.add_development_dependency "cucumber", "~> 3.1"
  s.add_development_dependency "rake", "~> 12.0"
  s.add_development_dependency "rspec", "~> 3.5"
  s.add_development_dependency "html-proofer", "~> 3.6"
  s.add_development_dependency "rubocop", "~> 0.48"
end
