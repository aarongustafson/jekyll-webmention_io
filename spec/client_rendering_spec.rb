# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe 'Client-side webmention rendering', type: :feature do
  def test_html_dir
    File.expand_path('tmp/client_rendering', __dir__)
  end

  def asset_path(name)
    File.expand_path("../lib/jekyll/assets/#{name}", __dir__)
  end

  let(:liquid_js_path) { asset_path('liquid.js') }
  let(:plugin_js_path) { asset_path('JekyllWebmentionIO.js') }
  let(:webmentions_template) do
    File.read(File.expand_path('../lib/jekyll/templates/webmentions.html', __dir__))
  end

  # A webmention.io read-API payload (one mention) in the shape addMetadata
  # expects. Typed as a "like" so addMetadata doesn't take the "post" branch
  # (which fires an XHR to fetch a title -- no network in tests).
  let(:payload) do
    {
      'links' => [{
        'id' => 12_345,
        'source' => 'https://example.com/a-mention',
        'verified_date' => '2025-12-13T12:00:00Z',
        'activity' => { 'type' => 'like', 'sentence_html' => 'liked this' },
        'data' => {
          'url' => 'https://example.com/a-mention',
          'published_ts' => 1_765_627_200,
          'author' => {
            'name' => 'Test User',
            'photo' => 'https://localhost/photo.jpg',
            'url' => 'https://localhost'
          }
        }
      }]
    }
  end

  before(:all) { FileUtils.mkdir_p(test_html_dir) }
  after(:all) { FileUtils.rm_rf(test_html_dir) }

  # Builds a page wired up the way the gem ships: the real assets, the template
  # embedded as a <script type="text/x-template"> (as the gem now emits it), and
  # the build-time `types` map the loader injects. Two collections let one
  # processWebmentions call exercise both render paths at once.
  def build_page
    html = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head><meta charset="UTF-8"><title>client rendering</title></head>
      <body>
        <!-- No list yet: exercises the replace path. -->
        <div class="webmentions" id="fresh"></div>

        <!-- Already has a rendered list: exercises the append path. -->
        <div class="webmentions" id="existing">
          <ol class="webmentions__list">
            <li id="webmention-999" class="webmention webmentions__item webmention--like">seed</li>
          </ol>
        </div>

        <script type="text/x-template" id="webmention-webmentions">#{webmentions_template}</script>

        <!-- Load the assets as external files, the way the gem ships them. (The
             plugin source contains a "</script>" in a comment, so inlining it
             would close the tag early -- a test-only footgun, not a bug.) -->
        <script src="file://#{liquid_js_path}"></script>
        <script src="file://#{plugin_js_path}"></script>
        <script>
          // Build-time injected globals (see CompileJS#add_webmention_types).
          window.JekyllWebmentionIO.types = { likes: 'like' };
        </script>
      </body>
      </html>
    HTML

    file = File.join(test_html_dir, 'pipeline.html')
    File.write(file, html)
    file
  end

  before do
    visit "file://#{build_page}"
    page.execute_script("window.JekyllWebmentionIO.processWebmentions(#{payload.to_json})")
  end

  it 'replaces a fresh collection with a populated list (no nested wrapper)' do
    within('#fresh') do
      # The list is grafted in directly -- not wrapped in another .webmentions.
      expect(page).to have_css('#fresh > .webmentions__list')
      expect(page).to have_css('.webmentions__list .webmentions__item', count: 1)
      expect(page).to have_css('#webmention-12345')
    end
  end

  it 'appends to an existing list, preserving the items already there' do
    within('#existing .webmentions__list') do
      expect(page).to have_css('.webmentions__item', count: 2)
      expect(page).to have_css('#webmention-999')   # seed preserved
      expect(page).to have_css('#webmention-12345') # new one appended
    end
  end

  it 'populates the author photo from the payload (the field in the report)' do
    img = within('#fresh') { find('.webmention__author__photo') }

    expect(img[:src]).to eq('https://localhost/photo.jpg')
    expect(img[:title]).to eq('Test User')
  end

  it 'leaves no unrendered Liquid placeholders in the rendered collection' do
    rendered = page.evaluate_script("document.getElementById('fresh').innerHTML")

    expect(rendered).not_to include('{{')
  end
end
