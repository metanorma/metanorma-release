# frozen_string_literal: true

RSpec.describe Metanorma::Release::Platform::Local::ConfigFetcher do
  let(:fetcher) { described_class.new }
  let(:channel_config_yaml) do
    <<~YAML
      channels:
        - public/standards
      defaults:
        visibility: public
    YAML
  end

  describe '#fetch' do
    it 'reads config from local path' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'config.yml')
        File.write(path, channel_config_yaml)
        source = "local:#{path}"
        config = fetcher.fetch(source)
        expect(config).not_to be_nil
        expect(config.registry.channels.length).to eq(1)
      end
    end

    it 'returns nil when file does not exist' do
      config = fetcher.fetch('local:/nonexistent/path.yml')
      expect(config).to be_nil
    end
  end
end
