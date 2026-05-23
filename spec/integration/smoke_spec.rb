# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative 'support/test_server'
require_relative 'support/static_server'
require_relative 'support/webmention_hub'
require_relative 'support/jekyll_site_builder'

# End-to-end smoke test for the webmention round trip, with no external services
# in the loop. A local hub plays both the receiver and the webmention.io read
# API; a local static server hosts the built site.
#
# The send and receive paths are exercised as separate examples so a failure
# points at exactly one half of the cycle. To keep them independent, the receive
# example seeds the hub directly rather than relying on the send example having
# run first, and the hub is cleared before each example.
RSpec.describe 'Webmention round trip', :integration do
  before(:all) do
    @root = Dir.mktmpdir('webmention-smoke')
    @hub = SmokeTest::WebmentionHub.new(SmokeTest.free_port).start
    @site_port = SmokeTest.free_port

    @builder = SmokeTest::JekyllSiteBuilder.new(
      root: @root,
      site_origin: "http://127.0.0.1:#{@site_port}",
      hub_endpoint: @hub.endpoint,
      hub_api_url: @hub.api_url
    )
    @builder.write_sources

    # Build once up front so there's a `_site` for the static server to host and
    # an outgoing-webmention cache for the send example to act on.
    build_site
    @static = SmokeTest::StaticServer.new(@site_port, @builder.destination).start
  end

  after(:all) do
    @static&.stop
    @hub&.stop
    FileUtils.remove_entry(@root) if @root && File.directory?(@root)
    Jekyll::WebmentionIO::Caches.reset
  end

  before { @hub.clear }

  # Each phase mirrors a fresh CLI invocation: reset the cache singletons so
  # state is reloaded from disk, then let the `:after_init` hook re-bootstrap
  # the plugin against the site's configuration.
  def build_site
    Jekyll::WebmentionIO::Caches.reset
    Jekyll::Site.new(@builder.configuration).process
  end

  def run_webmention_command
    Jekyll::WebmentionIO::Caches.reset
    Jekyll::Site.new(@builder.configuration)
    Jekyll::WebmentionIO::Commands::WebmentionCommand.send_webmentions
  end

  # Leg A: the queued webmention is sent and the receiver verifies it.
  it 'sends a queued webmention that the receiver verifies and stores' do
    run_webmention_command

    mention = @hub.mentions.find do |m|
      m.source == @builder.source_url && m.target == @builder.target_url
    end
    expect(mention).not_to(be_nil, 'the hub never received a verified webmention from the source post')
  end

  # Leg B: a received webmention is gathered back via the read API and rendered.
  it 'gathers a received webmention and renders it into the page' do
    @hub.seed(source: @builder.source_url, target: @builder.target_url)

    build_site

    rendered = File.read(@builder.target_output)
    expect(rendered).to include(@builder.source_url)
    expect(rendered).to include(SmokeTest::WebmentionHub::MENTION_CONTENT)
    expect(rendered).not_to include('No webmentions were found')
  end
end
