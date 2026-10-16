# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'yaml'
require 'safe_yaml/load'

RSpec.describe Jekyll::WebmentionIO::Caches do
  let(:temp_dir) { Dir.mktmpdir('jekyll_webmention_io_test') }
  let(:config) { double('Config', cache_folder: temp_dir) }
  let(:caches) { described_class.new(config) }

  before do
    # Clear any existing singleton instances
    described_class.reset
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe 'accessor methods' do
    # Path construction itself is covered by 'uses Jekyll.sanitized_path for path
    # construction' below; this only pins each accessor to its own cache file.
    it 'exposes each cache under its own file name' do
      {
        incoming_webmentions: 'webmention_io_incoming.yml',
        outgoing_webmentions: 'webmention_io_outgoing.yml',
        bad_uris: 'webmention_io_bad_uris.yml',
        site_lookups: 'webmention_io_lookups.yml'
      }.each do |accessor, filename|
        expect(caches.public_send(accessor).path).to end_with(filename)
      end
    end
  end

  describe 'Cache class' do
    # Because we can't directly initialize the Cache class, we're just going to pick
    # one of them that we can use for our behavioural tests.
    let(:cache) { caches.incoming_webmentions }
    let(:mentions) { { '1' => { 'raw' => { 'target' => 'https://example.com/page.html' } } } }

    describe 'initialization' do
      context 'when cache file exists and is valid YAML' do
        before do
          FileUtils.mkdir_p(File.dirname(cache.path))
          File.write(cache.path, YAML.dump({ 'existing_key' => mentions }))
          # Clear singleton and create new instance to test loading
          described_class.reset
          @new_cache = caches.incoming_webmentions
        end

        it 'loads existing data from file' do
          expect(@new_cache['existing_key'].webmentions).to eq(mentions)
        end

        it 'reads the URLs the mentions came back under' do
          expect(@new_cache['existing_key'].canonical_urls).to eq(['https://example.com/page.html'])
        end
      end

      context 'when cache file does not exist' do
        it 'initializes with empty hash' do
          expect(cache.empty?).to be true
        end
      end

      context 'when cache file exists but is invalid YAML' do
        before do
          FileUtils.mkdir_p(File.dirname(cache.path))
          File.write(cache.path, 'invalid yaml content: [')
          # Clear singleton and create new instance to test error handling
          described_class.reset
          @new_cache = caches.incoming_webmentions
        end

        it 'initializes with empty hash and handles error gracefully' do
          expect(@new_cache.empty?).to be true
        end
      end

      context 'when cache file exists but is empty' do
        before do
          FileUtils.mkdir_p(File.dirname(cache.path))
          File.write(cache.path, '')
          # Clear singleton and create new instance to test empty file handling
          described_class.reset
          @new_cache = caches.incoming_webmentions
        end

        it 'starts empty' do
          # SafeYAML.load_file returns false for an empty file rather than raising, so
          # this is the branch that has to leave the cache usable.
          expect(@new_cache.empty?).to be true
        end
      end
    end

    describe 'hash-like behavior' do
      it 'supports iteration with each' do
        cache.store('key1', mentions)
        cache.store('key2', mentions)

        collected = {}
        cache.each { |key, entry| collected[key] = entry.webmentions }

        expect(collected).to eq('key1' => mentions, 'key2' => mentions)
      end

      it 'creates an entry on demand' do
        expect(cache.entry('new_key').webmentions).to eq({})
        expect(cache.key?('new_key')).to be true
      end

      it 'behaves like a hash for storage, retrieval, presence and deletion' do
        expect(cache.empty?).to be true

        cache.store('test_key', mentions)

        expect(cache.empty?).to be false
        expect(cache['test_key'].webmentions).to eq(mentions)
        expect(cache.key?('test_key')).to be true
        expect(cache.key?('nonexistent')).to be false

        expect(cache.delete('test_key').webmentions).to eq(mentions)
        expect(cache.key?('test_key')).to be false
      end
    end

    describe '#write' do
      it 'writes the entries in YAML format' do
        FileUtils.mkdir_p(File.dirname(cache.path))

        cache.store('test_key', mentions)

        cache.write

        expect(File.exist?(cache.path)).to be true
        expect(YAML.load_file(cache.path)).to eq(
          'test_key' => { 'webmentions' => mentions, 'canonical_urls' => ['https://example.com/page.html'] }
        )
      end

      it 'overwrites existing file content' do
        FileUtils.mkdir_p(File.dirname(cache.path))

        # Write initial data
        cache.store('initial', {})
        cache.write

        # Modify and write again
        cache.store('initial', mentions)
        cache.store('new', {})
        cache.write

        expect(YAML.load_file(cache.path)).to eq(
          'initial' => { 'webmentions' => mentions, 'canonical_urls' => ['https://example.com/page.html'] },
          'new' => { 'webmentions' => {}, 'canonical_urls' => [] }
        )
      end
    end

    describe '#clear' do
      it 'clears internal data' do
        FileUtils.mkdir_p(File.dirname(cache.path))

        cache.store('key1', mentions)
        cache.store('key2', mentions)
        cache.write
        expect(cache.empty?).to be false

        cache.clear
        expect(cache.empty?).to be true
      end

      it 'deletes the cache file when it exists' do
        FileUtils.mkdir_p(File.dirname(cache.path))

        cache.store('test', mentions)
        cache.write
        expect(File.exist?(cache.path)).to be true

        cache.clear
        expect(File.exist?(cache.path)).to be false
      end

      it 'handles non-existent file gracefully' do
        # The clear method should not raise an error when the file doesn't exist
        expect { cache.clear }.not_to raise_error
        expect(cache.empty?).to be true
      end
    end

    describe 'round-tripping a lookup date' do
      it 'reads back the date it wrote' do
        caches.site_lookups.store('/page.html', Date.today)
        caches.site_lookups.write

        described_class.reset

        expect(caches.site_lookups['/page.html'].last_check_date).to eq(Date.today)
      end
    end
  end

  describe 'cache file path generation' do
    it 'uses Jekyll.sanitized_path for path construction' do
      allow(Jekyll).to receive(:sanitized_path).and_call_original
      caches.incoming_webmentions
      expect(Jekyll).to have_received(:sanitized_path).with(temp_dir, 'webmention_io_incoming.yml')
    end
  end

  describe 'error handling' do
    context 'when cache folder cannot be created' do
      # A regular file in the path is unwritable regardless of the user running the
      # suite, where a permissions-based path is still writable when run as root.
      let(:blocking_file) { File.join(temp_dir, 'not-a-directory') }
      let(:config_with_blocked_folder) { double('Config', cache_folder: File.join(blocking_file, 'cache')) }

      before do
        File.write(blocking_file, '')
      end

      it 'raises an error during initialization' do
        expect { described_class.new(config_with_blocked_folder) }.to raise_error(SystemCallError)
      end
    end
  end
end
