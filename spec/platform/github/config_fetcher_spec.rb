# frozen_string_literal: true

require_relative '../../../lib/metanorma/release/platform/github'

RSpec.describe Metanorma::Release::Platform::GitHub::ConfigFetcher do
  let(:mock_client) { double('Octokit::Client') }
  let(:fetcher) { described_class.new(client: mock_client) }

  let(:channel_config_yaml) do
    <<~YAML
      channels:
        - public/standards
      defaults:
        visibility: public
    YAML
  end

  let(:encoded_content) { Base64.strict_encode64(channel_config_yaml) }

  describe '#fetch' do
    it 'fetches config from repo with explicit path' do
      allow(mock_client).to receive(:contents)
        .with('myorg/myrepo', path: 'path/to/channels.yml')
        .and_return({ 'content' => encoded_content })

      config = fetcher.fetch('myorg/myrepo#path/to/channels.yml')
      expect(config).not_to be_nil
      expect(config.registry.channels.length).to eq(1)
    end

    it 'defaults to channels.yml when no path specified' do
      allow(mock_client).to receive(:contents)
        .with('myorg/myrepo', path: 'channels.yml')
        .and_return({ 'content' => encoded_content })

      config = fetcher.fetch('myorg/myrepo')
      expect(config).not_to be_nil
    end

    it 'returns nil on error' do
      allow(mock_client).to receive(:contents)
        .and_raise(StandardError, 'not found')

      config = fetcher.fetch('myorg/myrepo')
      expect(config).to be_nil
    end
  end
end
