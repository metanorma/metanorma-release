# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Metanorma::Release::AggregateConfig do
  describe '.load' do
    it 'loads config from explicit path' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'test.yml')
        File.write(config_path, <<~YAML)
          source: github
          output_dir: _site/docs
          github:
            organizations:
              - MyOrg
            topic: my-topic
            repo_pattern: "doc-*"
        YAML

        config = described_class.load(config_path)
        expect(config.source).to eq('github')
        expect(config.organizations).to eq(['MyOrg'])
        expect(config.topic).to eq('my-topic')
        expect(config.repo_pattern).to eq('doc-*')
        expect(config.output_dir).to eq('_site/docs')
      end
    end

    it 'returns defaults when no config file found' do
      config = described_class.load('/nonexistent/path.yml')
      expect(config.source).to eq('github')
      expect(config.organizations).to eq([])
      expect(config.output_dir).to eq('_site/cc')
    end

    it 'parses local source with path' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'local.yml')
        File.write(config_path, <<~YAML)
          source: local
          local:
            path: /data/docs
        YAML

        config = described_class.load(config_path)
        expect(config.source).to eq('local')
        expect(config.local_path).to eq('/data/docs')
      end
    end

    it 'parses content filters' do
      Dir.mktmpdir do |dir|
        config_path = File.join(dir, 'filters.yml')
        File.write(config_path, <<~YAML)
          source: github
          channels:
            - public/standards
          stages:
            - published
          file_routing: flat
          github:
            organizations:
              - TestOrg
        YAML

        config = described_class.load(config_path)
        expect(config.channels).to eq(['public/standards'])
        expect(config.stages).to eq(['published'])
        expect(config.file_routing).to eq('flat')
      end
    end
  end
end
