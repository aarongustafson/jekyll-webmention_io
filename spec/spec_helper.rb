# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'jekyll'
require 'jekyll-webmention_io'
require 'html-proofer'
require 'json'
require 'capybara/rspec'
require 'capybara/cuprite'

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800])
end
Capybara.javascript_driver = :cuprite
Capybara.default_driver = :cuprite

Dir[File.expand_path('support/**/*.rb', __dir__)].sort.each { |f| require f }

ENV['JEKYLL_LOG_LEVEL'] = 'error'

RSpec.configure do |config|
  config.include Capybara::DSL, type: :feature
end
