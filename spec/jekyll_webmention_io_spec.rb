# frozen_string_literal: true

require 'spec_helper'

describe Jekyll::WebmentionIO do
  let(:dest_dir) { File.expand_path('../tmp/dest', __dir__) }
  let(:source_dir) { File.expand_path('fixtures', __dir__) }
  let(:config_defaults) do
    {
      'source' => source_dir,
      'destination' => dest_dir,
      'gems' => ['jekyll-webmention_io']
    }.freeze
  end

  let(:page) { Jekyll::Page.new site, config_defaults['source'], '', 'page.md' }
  let(:post) do
    Jekyll::Document.new(
      File.expand_path('_posts/2001-01-01-post.md', config_defaults['source']),
      { site: site, collection: site.collections['posts'] }
    )
  end
  let(:site) { Jekyll::Site.new(Jekyll.configuration(config_defaults)) }
  let(:context) { make_context(page: page, site: site) }

  before do
    Jekyll.logger.log_level = :error
  end

  it 'outputs valid HTML' do
    site.process
    # html-proofer 5.x dropped the old `check_html`/`checks_to_ignore` options and
    # raises (rather than returning a boolean) when it finds failures. Keep the
    # check offline and don't flag the fixtures' intentional non-HTTPS/external
    # links, so we're asserting the plugin's *internal* markup is sound.
    options = {
      disable_external: true,
      enforce_https: false
    }
    expect { HTMLProofer.check_directory(dest_dir, options).run }.not_to raise_error
  end
end
