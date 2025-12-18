# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'nokogiri'

RSpec.describe 'Template Rendering' do
  # Shared context for browser-based testing with Capybara
  shared_context 'capybara_browser' do
    def test_html_dir
      File.expand_path('../tmp/template_tests', __dir__)
    end

    let(:liquid_js_path) { File.expand_path('../lib/jekyll/assets/liquid.js', __dir__) }
    let(:liquid_js) { File.read(liquid_js_path) }

    before(:all) do
      FileUtils.mkdir_p(test_html_dir)
    end

    after(:all) do
      FileUtils.rm_rf(test_html_dir)
    end

    def create_test_page(template_html, test_name, data = {})
      html = <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>Template Test: #{test_name}</title>
        </head>
        <body>
          <div id="output"></div>
          <template id="webmention-test">#{template_html}</template>

          <script>#{liquid_js}</script>
          <script>
            document.addEventListener('DOMContentLoaded', function() {
              window.testData = #{data.to_json};
              window.testResult = null;

              try {
                var template = document.getElementById('webmention-test');
                var templateContent = template.innerHTML;
                var parsed = Liquid.parse(templateContent);
                var rendered = parsed.render(window.testData);
                window.testResult = {
                  success: true,
                  result: rendered,
                  templateContent: templateContent
                };
                document.getElementById('output').innerHTML = rendered;
              } catch(e) {
                window.testResult = {
                  success: false,
                  error: String(e),
                  message: e.message || String(e),
                  templateContent: template ? template.innerHTML : 'N/A'
                };
              }
            });
          </script>
        </body>
        </html>
      HTML

      test_file = File.join(test_html_dir, "#{test_name}.html")
      File.write(test_file, html)
      test_file
    end
  end

  # Template data factories
  def webmention_with_author(type)
    {
      'webmentions' => [{
        'id' => '12345',
        'type' => type,
        'author' => {
          'name' => 'Test User',
          'photo' => 'https://localhost/photo.jpg',
          'url' => 'https://localhost'
        },
        'content' => 'Great post!',
        'pubdate' => '2025-12-13T12:00:00-07:00',
        'uri' => 'https://localhost/mention'
      }],
      'types' => ['replies']
    }
  end

  # Helper for structural comparison
  def structurally_equal?(doc1, doc2, &block)
    return false unless doc1.instance_of?(doc2.class) &&
                        doc1.name == doc2.name &&
                        doc1.attributes.size == doc2.attributes.size

    # Compare attributes, ignoring order
    attrs1 = doc1.attributes.transform_values(&:to_s).sort.to_h
    attrs2 = doc2.attributes.transform_values(&:to_s).sort.to_h
    return false unless attrs1 == attrs2

    # Compare children, ignoring whitespace-only text nodes
    children1 = doc1.children.reject { |c| c.text? && c.text.strip.empty? }
    children2 = doc2.children.reject { |c| c.text? && c.text.strip.empty? }

    return false unless children1.size == children2.size

    children1.zip(children2).all? do |c1, c2|
      if c1.text? && c2.text?
        c1.text.strip == c2.text.strip
      elsif c1.element? && c2.element?
        structurally_equal?(c1, c2, &block)
      else
        false # Mismatched node types
      end
    end
  end

  # Shared examples for structural equivalence between client and server rendering
  shared_examples 'structurally equivalent' do
    include_context 'capybara_browser'

    let(:template_path) { File.expand_path("../lib/jekyll/templates/#{template_name}.html", __dir__) }
    let(:template) { File.read(template_path) }

    it 'produces structurally identical DOM trees' do
      # 1. Server-side rendering
      liquid = Liquid::Template.parse(template)
      server_html = liquid.render(template_data)
      server_doc = Nokogiri::HTML.fragment(server_html)

      # 2. Client-side rendering
      test_file = create_test_page(template, "#{template_name}_structural", template_data)
      visit "file://#{test_file}"
      client_html = evaluate_script("document.getElementById('output').innerHTML")
      client_doc = Nokogiri::HTML.fragment(client_html)

      # 3. Compare
      expect(structurally_equal?(server_doc, client_doc)).to be(true), "DOM structures do not match.\n\nServer:\n#{server_doc.to_html}\n\nClient:\n#{client_doc.to_html}"
    end
  end

  # Shared examples for server-side Ruby Liquid rendering
  shared_examples 'renders correctly with Ruby Liquid' do
    let(:template_path) { File.expand_path("../lib/jekyll/templates/#{template_name}.html", __dir__) }
    let(:template) { File.read(template_path) }
    let(:webmention) { template_data['webmentions'].first }

    let(:expected_text) { nil }

    it 'parses and renders without errors' do
      liquid = Liquid::Template.parse(template)
      expect {
        liquid.render(template_data)
      }.not_to raise_error
    end

    it 'honours html_proofer_ignore' do
      liquid = Liquid::Template.parse(template)
      page = Nokogiri::HTML.fragment(liquid.render(template_data.merge('html_proofer_ignore' => 'all')))

      expect(page.at_css('div.webmentions')['data-proofer-ignore']).not_to be_nil
    end

    it 'includes expected content when data is present' do
      liquid = Liquid::Template.parse(template)
      page = Nokogiri::HTML.fragment(liquid.render(template_data))

      # Check for presence of the wrapping div for the webmentions list
      expect(page.at_css('.webmentions__list')).not_to be_nil

      # Check for webmention content
      expect(page.at_css('.webmention__author__name').text).to include(webmention['author']['name'])
      expect(page.at_css('.webmention__content').text).to include(expected_text) if !expected_text.nil?

      author_url = page.at_css('.u-url')

      expect(author_url).not_to be_nil
      expect(author_url['href']).to include(webmention['author']['url'])

      img = page.at_css('.webmention__author__photo')

      expect(img).not_to be_nil
      expect(img['src']).to eq(webmention['author']['photo'])
      expect(img['title']).to eq(webmention['author']['name'])
    end

    it 'handles empty webmentions array' do
      liquid = Liquid::Template.parse(template)
      result = liquid.render('webmentions' => [])

      expect(result).to include(empty_message)
    end
  end

  # Shared examples for client-side liquid.js rendering
  shared_examples 'renders correctly with liquid.js in browser' do
    include_context 'capybara_browser'

    let(:template_path) { File.expand_path("../lib/jekyll/templates/#{template_name}.html", __dir__) }
    let(:template) { File.read(template_path) }
    let(:webmention) { template_data['webmentions'].first }

    let(:expected_text) { nil }

    it 'parses and renders without errors in real browser' do
      test_file = create_test_page(template, "#{template_name}_basic", template_data)
      visit "file://#{test_file}"

      result = evaluate_script('window.testResult')

      expect(result['success']).to be(true), "liquid.js failed: #{result['error']}\nTemplate innerHTML: #{result['templateContent']}"
    end

    it 'honours html_proofer_ignore' do
      test_file = create_test_page(template, "#{template_name}_content", template_data.merge('html_proofer_ignore' => 'all'))
      visit "file://#{test_file}"

      div = find('div.webmentions')

      expect(div[:'data-proofer-ignore']).not_to be_nil
    end

    it 'includes expected content when data is present' do
      test_file = create_test_page(template, "#{template_name}_content", template_data)
      visit "file://#{test_file}"

      expect(page).to have_css(".webmentions--#{webmention['type']}") unless webmention['type'] == 'mention'

      # Check for presence of the wrapping div for the webmentions list
      expect(page).to have_css('.webmentions__list')

      # Check for webmention content
      within('.webmention__author__name') do
        expect(page).to have_content(webmention['author']['name'])
      end

      if !expected_text.nil?
        within('.webmention__content') do
          expect(page).to have_content(expected_text)
        end
      end

      expect(page).to have_css("a.u-url[href='#{webmention['author']['url']}']")

      img = find('.webmention__author__photo')

      expect(img[:title]).to eq(webmention['author']['name'])
      expect(img[:src]).to eq(webmention['author']['photo'])
    end

    it 'handles empty webmentions array' do
      test_file = create_test_page(template, "#{template_name}_empty", { 'webmentions' => [] })
      visit "file://#{test_file}"

      expect(page).to have_content(empty_message)
    end
  end

  # Test each template type
  describe 'bookmarks.html' do
    let(:template_name) { 'bookmarks' }
    let(:template_data) { webmention_with_author(template_name) }
    let(:expected_text) { 'Great post!' }
    let(:empty_message) { 'No bookmarks were found' }

    describe 'Server-side' do
      it_behaves_like 'renders correctly with Ruby Liquid'
    end

    describe 'Client-side', type: :feature do
      it_behaves_like 'renders correctly with liquid.js in browser'
    end

    describe 'Structural equivalence', type: :feature do
      it_behaves_like 'structurally equivalent'
    end
  end

  describe 'likes.html' do
    let(:template_name) { 'likes' }
    let(:template_data) { webmention_with_author(template_name) }
    let(:empty_message) { 'No likes have been sent yet!' }

    describe 'Server-side' do
      it_behaves_like 'renders correctly with Ruby Liquid'
    end

    describe 'Client-side', type: :feature do
      it_behaves_like 'renders correctly with liquid.js in browser'
    end

    describe 'Structural equivalence', type: :feature do
      it_behaves_like 'structurally equivalent'
    end
  end

  describe 'links.html' do
    let(:template_name) { 'links' }
    let(:template_data) { webmention_with_author(template_name) }
    let(:expected_text) { 'Great post!' }
    let(:empty_message) { 'No links were found' }

    describe 'Server-side' do
      it_behaves_like 'renders correctly with Ruby Liquid'
    end

    describe 'Client-side', type: :feature do
      it_behaves_like 'renders correctly with liquid.js in browser'
    end

    describe 'Structural equivalence', type: :feature do
      it_behaves_like 'structurally equivalent'
    end
  end

  describe 'posts.html' do
    let(:template_name) { 'posts' }
    let(:template_data) { webmention_with_author(template_name) }
    let(:expected_text) { 'Great post!' }
    let(:empty_message) { 'No posts were found' }

    describe 'Server-side' do
      it_behaves_like 'renders correctly with Ruby Liquid'
    end

    describe 'Client-side', type: :feature do
      it_behaves_like 'renders correctly with liquid.js in browser'
    end

    describe 'Structural equivalence', type: :feature do
      it_behaves_like 'structurally equivalent'
    end
  end

  describe 'replies.html' do
    let(:template_name) { 'replies' }
    let(:template_data) { webmention_with_author(template_name) }
    let(:expected_text) { 'Great post!' }
    let(:empty_message) { 'No replies were found' }

    describe 'Server-side' do
      it_behaves_like 'renders correctly with Ruby Liquid'
    end

    describe 'Client-side', type: :feature do
      it_behaves_like 'renders correctly with liquid.js in browser'
    end

    describe 'Structural equivalence', type: :feature do
      it_behaves_like 'structurally equivalent'
    end
  end

  describe 'reposts.html' do
    let(:template_name) { 'reposts' }
    let(:template_data) { webmention_with_author(template_name) }
    let(:empty_message) { 'No reposts were found' }

    describe 'Server-side' do
      it_behaves_like 'renders correctly with Ruby Liquid'
    end

    describe 'Client-side', type: :feature do
      it_behaves_like 'renders correctly with liquid.js in browser'
    end

    describe 'Structural equivalence', type: :feature do
      it_behaves_like 'structurally equivalent'
    end
  end

  describe 'rsvps.html' do
    let(:template_name) { 'rsvps' }
    let(:template_data) { webmention_with_author(template_name) }
    let(:empty_message) { 'No RSVPs were found' }

    describe 'Server-side' do
      it_behaves_like 'renders correctly with Ruby Liquid'
    end

    describe 'Client-side', type: :feature do
      it_behaves_like 'renders correctly with liquid.js in browser'
    end

    describe 'Structural equivalence', type: :feature do
      it_behaves_like 'structurally equivalent'
    end
  end

  describe 'webmentions.html' do
    let(:template_name) { 'webmentions' }
    let(:template_data) { webmention_with_author('mention') }
    let(:expected_text) { 'Great post!' }
    let(:empty_message) { 'No webmentions were found' }

    describe 'Server-side' do
      it_behaves_like 'renders correctly with Ruby Liquid'
    end

    describe 'Client-side', type: :feature do
      it_behaves_like 'renders correctly with liquid.js in browser'
    end

    describe 'Structural equivalence', type: :feature do
      it_behaves_like 'structurally equivalent'
    end
  end
end
