require 'spec_helper'

describe Jekyll::WebmentionIO do
  let(:dest_dir) { File.expand_path('../tmp/dest', __dir__) }
  let(:source_dir) { File.expand_path('fixtures', __dir__) }
  let(:config_defaults) do
    {
      'source'      => source_dir,
      'destination' => dest_dir,
      'gems'        => ['jekyll-webmention_io'],
    }.freeze
  end

  let(:page) { Jekyll::Page.new site, config_defaults['source'], '', 'page.md' }
  let(:post) do 
    Jekyll::Document.new(
      File.expand_path('_posts/2001-01-01-post.md', config_defaults['source']),
      { :site => site, :collection => site.collections['posts'] }
    )
  end
  let(:site) { Jekyll::Site.new(Jekyll.configuration(config_defaults)) }
  let(:context) { make_context(:page => page, :site => site) }

  before do
    Jekyll.logger.log_level = :error
  end

  it 'outputs valid HTML' do
    site.process
    options = {
      :check_html       => true,
      :checks_to_ignore => %w(ScriptCheck LinkCheck ImageCheck),
    }
    status = HTMLProofer.check_directory(dest_dir, options).run
    expect(status).to eql(true)
  end
end
