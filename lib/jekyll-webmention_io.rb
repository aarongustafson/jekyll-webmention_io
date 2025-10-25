# frozen_string_literal: false

require 'jekyll'
require 'jekyll/webmention_io'

Jekyll::Hooks.register :site, :after_init do |site|
  Jekyll::WebmentionIO.bootstrap(site)
end
