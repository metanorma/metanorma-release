# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Metanorma::Release::DeltaState do
  let(:tmpdir) { Dir.mktmpdir }
  let(:cache) { Metanorma::Release::FileCacheStore.new(Dir.mktmpdir) }
  let(:output_dir) { Dir.mktmpdir }
  let(:state) { described_class.new(cache_store: cache, output_dir: output_dir) }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe 'ETag management' do
    it 'gets and sets ETag' do
      state.set_etag('CalConnect/cc-datetime', 'abc123')
      expect(state.etag('CalConnect/cc-datetime')).to eq('abc123')
    end

    it 'returns nil for unknown repo' do
      expect(state.etag('unknown/repo')).to be_nil
    end
  end

  describe 'release dedup' do
    it 'returns false for new release' do
      expect(state.processed?('repo/key', 'cc-18011/ed1', 'hash123')).to be false
    end

    it 'returns true after marking processed' do
      state.mark_processed('repo/key', 'cc-18011/ed1', 'hash123', ['file.html'])
      expect(state.processed?('repo/key', 'cc-18011/ed1', 'hash123')).to be true
    end

    it 'returns false when content hash differs' do
      state.mark_processed('repo/key', 'cc-18011/ed1', 'hash123', ['file.html'])
      expect(state.processed?('repo/key', 'cc-18011/ed1', 'different')).to be false
    end

    it 'returns false for nil content hash' do
      state.mark_processed('repo/key', 'cc-18011/ed1', 'hash123', ['file.html'])
      expect(state.processed?('repo/key', 'cc-18011/ed1', nil)).to be false
    end

    it 'returns release files' do
      state.mark_processed('repo/key', 'cc-18011/ed1', 'hash', %w[file.html file.pdf])
      expect(state.release_files('repo/key', 'cc-18011/ed1')).to eq(%w[file.html file.pdf])
    end

    it 'returns empty array for unknown release' do
      expect(state.release_files('repo/key', 'unknown/tag')).to eq([])
    end
  end

  describe 'stale cleanup' do
    it 'removes files for tags no longer in current set' do
      file_path = File.join(output_dir, 'stale.html')
      File.write(file_path, 'old content')
      state.mark_processed('repo/key', 'stale/tag', 'hash', ['stale.html'])

      removed = state.cleanup_stale('repo/key', ['current/tag'])
      expect(removed).to eq(1)
      expect(File.exist?(file_path)).to be false
    end

    it 'keeps files for current tags' do
      file_path = File.join(output_dir, 'current.html')
      File.write(file_path, 'content')
      state.mark_processed('repo/key', 'current/tag', 'hash', ['current.html'])

      state.cleanup_stale('repo/key', ['current/tag'])
      expect(File.exist?(file_path)).to be true
    end

    it 'handles missing files gracefully' do
      state.mark_processed('repo/key', 'gone/tag', 'hash', ['nonexistent.html'])
      removed = state.cleanup_stale('repo/key', [])
      expect(removed).to eq(0)
    end
  end

  describe 'persistence' do
    it 'round-trips through save and load' do
      state.set_etag('repo/key', 'etag123')
      state.mark_processed('repo/key', 'tag1', 'hash1', ['file.html'])
      state.save

      state2 = described_class.new(cache_store: cache, output_dir: output_dir)
      state2.load
      expect(state2.etag('repo/key')).to eq('etag123')
      expect(state2.processed?('repo/key', 'tag1', 'hash1')).to be true
    end

    it 'resets on invalid JSON' do
      cache.set('delta_state', 'not json{}')
      state.load
      expect(state.etag('any')).to be_nil
    end
  end
end

RSpec.describe Metanorma::Release::NullDeltaState do
  let(:state) { described_class.new }

  it 'processed? always returns false' do
    expect(state.processed?('a', 'b', 'c')).to be false
  end

  it 'cleanup_stale always returns 0' do
    expect(state.cleanup_stale('a', [])).to eq(0)
  end

  it 'release_files returns empty array' do
    expect(state.release_files('a', 'b')).to eq([])
  end
end
