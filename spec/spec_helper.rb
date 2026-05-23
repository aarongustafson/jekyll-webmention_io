# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/bundle/'
    add_filter '/.claude/'

    add_group 'Library', 'lib'

    enable_coverage :branch
  end
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'jekyll'
require 'jekyll-webmention_io'
require 'html-proofer'
require 'json'
require 'capybara/rspec'
require 'capybara/cuprite'

Capybara.register_driver(:cuprite) do |app|
  # process_timeout guards browser startup; the 10s default is occasionally too
  # tight on loaded CI runners, producing flaky Ferrum::ProcessTimeoutError.
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800], process_timeout: 30)
end
Capybara.javascript_driver = :cuprite
Capybara.default_driver = :cuprite

Dir[File.expand_path('support/**/*.rb', __dir__)].sort.each { |f| require f }

ENV['JEKYLL_LOG_LEVEL'] = 'error'

RSpec.configure do |config|
  config.include Capybara::DSL, type: :feature
end
