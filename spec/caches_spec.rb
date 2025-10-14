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
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  describe 'accessor methods' do
    describe '#incoming_webmentions' do
      it 'creates cache file with correct path' do
        cache = caches.incoming_webmentions
        expect(cache.path).to end_with('webmention_io_incoming.yml')
      end
    end

    describe '#outgoing_webmentions' do
      it 'creates cache file with correct path' do
        cache = caches.outgoing_webmentions
        expect(cache.path).to end_with('webmention_io_outgoing.yml')
      end
    end

    describe '#bad_uris' do
      it 'creates cache file with correct path' do
        cache = caches.bad_uris
        expect(cache.path).to end_with('webmention_io_bad_uris.yml')
      end
    end

    describe '#site_lookups' do
      it 'creates cache file with correct path' do
        cache = caches.site_lookups
        expect(cache.path).to end_with('webmention_io_lookups.yml')
      end
    end
  end

  describe 'Cache class' do
    # Because we can't directly initialize the Cache class, we're just going to pick
    # one of them that we can use for our behavioural tests.
    let(:cache) { caches.incoming_webmentions }

    describe 'initialization' do
      context 'when cache file exists and is valid YAML' do
        before do
          FileUtils.mkdir_p(File.dirname(cache.path))
          File.write(cache.path, YAML.dump({ 'existing_key' => 'existing_value' }))
          # Clear singleton and create new instance to test loading
          described_class.reset
          @new_cache = caches.incoming_webmentions
        end

        it 'loads existing data from file' do
          expect(@new_cache['existing_key']).to eq('existing_value')
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

        it 'initializes with false for empty file' do
          # SafeYAML.load_file returns false for empty files, and this doesn't raise an exception
          # so the rescue block doesn't catch it
          expect(@new_cache.instance_variable_get(:@data)).to eq(false)
        end
      end
    end

    describe 'hash-like behavior' do
      it 'supports iteration with each' do
        cache['key1'] = 'value1'
        cache['key2'] = 'value2'

        collected = []
        cache.each { |k, v| collected << [k, v] }
        expect(collected).to contain_exactly(['key1', 'value1'], ['key2', 'value2'])
      end

      it 'supports key existence checking' do
        cache['test_key'] = 'test_value'
        expect(cache.key?('test_key')).to be true
        expect(cache.key?('nonexistent')).to be false
      end

      it 'supports key deletion' do
        cache['key_to_delete'] = 'value'
        expect(cache.key?('key_to_delete')).to be true

        deleted_value = cache.delete('key_to_delete')
        expect(deleted_value).to eq('value')
        expect(cache.key?('key_to_delete')).to be false
      end

      it 'supports nested value access with dig' do
        cache['nested'] = { 'inner' => { 'deep' => 'value' } }
        expect(cache.dig('nested', 'inner', 'deep')).to eq('value')
        expect(cache.dig('nested', 'inner', 'nonexistent')).to be_nil
      end

      it 'supports key-value assignment and retrieval' do
        cache['test_key'] = 'test_value'
        expect(cache['test_key']).to eq('test_value')
      end

      it 'supports empty checking' do
        expect(cache.empty?).to be true
        cache['key'] = 'value'
        expect(cache.empty?).to be false
      end
    end

    describe '#write' do
      it 'writes data to file in YAML format' do
        FileUtils.mkdir_p(File.dirname(cache.path))

        cache['test_key'] = 'test_value'
        cache['nested'] = { 'inner' => 'value' }

        cache.write

        expect(File.exist?(cache.path)).to be true
        loaded_data = YAML.load_file(cache.path)
        expect(loaded_data).to eq(
          {
            'test_key' => 'test_value',
            'nested' => { 'inner' => 'value' }
          }
        )
      end

      it 'overwrites existing file content' do
        FileUtils.mkdir_p(File.dirname(cache.path))

        # Write initial data
        cache['initial'] = 'data'
        cache.write

        # Modify and write again
        cache['initial'] = 'modified'
        cache['new'] = 'data'
        cache.write

        loaded_data = YAML.load_file(cache.path)
        expect(loaded_data).to eq(
          {
            'initial' => 'modified',
            'new' => 'data'
          }
        )
      end
    end

    describe '#clear' do
      it 'clears internal data' do
        FileUtils.mkdir_p(File.dirname(cache.path))

        cache['key1'] = 'value1'
        cache['key2'] = 'value2'
        cache.write
        expect(cache.empty?).to be false

        cache.clear
        expect(cache.empty?).to be true
      end

      it 'deletes the cache file when it exists' do
        FileUtils.mkdir_p(File.dirname(cache.path))

        cache['test'] = 'value'
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
      let(:readonly_dir) { '/root/readonly' }
      let(:config_with_readonly) { double('Config', cache_folder: readonly_dir) }

      it 'raises an error during initialization' do
        expect { described_class.new(config_with_readonly) }.to raise_error(Errno::EACCES)
      end
    end
  end
end
