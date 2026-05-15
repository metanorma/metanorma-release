# frozen_string_literal: true

RSpec.describe Metanorma::Release::ConfigResolver do
  let(:resolver) do
    obj = Object.new
    obj.extend(described_class)
    obj
  end

  describe '#load_manifest' do
    it 'returns nil for missing file' do
      expect(resolver.load_manifest('nonexistent.yml')).to be_nil
    end

    it 'returns nil for nil path' do
      expect(resolver.load_manifest(nil)).to be_nil
    end

    it 'loads manifest from file' do
      dir = Dir.mktmpdir
      path = File.join(dir, 'test.yml')
      File.write(path, "defaults:\n  visibility: public\n")
      manifest = resolver.load_manifest(path)
      expect(manifest).to be_a(Metanorma::Release::ChannelManifest)
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  describe '#resolve_channel_config' do
    it 'returns empty config when no source or manifest' do
      config = resolver.resolve_channel_config(nil, nil)
      expect(config).to be_a(Metanorma::Release::ChannelConfig)
    end

    it 'returns empty config when manifest has no config_source' do
      manifest = instance_double(Metanorma::Release::ChannelManifest, config_source: nil)
      config = resolver.resolve_channel_config(nil, manifest)
      expect(config).to be_a(Metanorma::Release::ChannelConfig)
    end

    it 'fetches config from local source' do
      dir = Dir.mktmpdir
      path = File.join(dir, 'channels.yml')
      File.write(path, "channels:\n  - public/default\n")
      allow(Metanorma::Release::ConfigLocator).to receive(:find).and_return(nil)

      config = resolver.resolve_channel_config("local:#{path}", nil)
      expect(config).to be_a(Metanorma::Release::ChannelConfig)
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
