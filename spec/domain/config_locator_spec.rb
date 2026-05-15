# frozen_string_literal: true

RSpec.describe Metanorma::Release::ConfigLocator do
  let(:channel_config_yaml) do
    <<~YAML
      channels:
        - public/standards
      defaults:
        visibility: public
    YAML
  end

  describe '.find' do
    it 'finds .metanorma.yml in the start directory' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.metanorma.yml'), channel_config_yaml)
        config = described_class.find(dir)
        expect(config).not_to be_nil
        expect(config.registry.channels.length).to eq(1)
      end
    end

    it 'finds .metanorma.yaml in the start directory' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.metanorma.yaml'), channel_config_yaml)
        config = described_class.find(dir)
        expect(config).not_to be_nil
        expect(config.registry.channels.length).to eq(1)
      end
    end

    it 'finds .metanorma/channels.yml in the start directory' do
      Dir.mktmpdir do |dir|
        subdir = File.join(dir, '.metanorma')
        Dir.mkdir(subdir)
        File.write(File.join(subdir, 'channels.yml'), channel_config_yaml)
        config = described_class.find(dir)
        expect(config).not_to be_nil
        expect(config.registry.channels.length).to eq(1)
      end
    end

    it 'walks up to parent directories' do
      Dir.mktmpdir do |root|
        File.write(File.join(root, '.metanorma.yml'), channel_config_yaml)
        child = File.join(root, 'subdir')
        Dir.mkdir(child)
        config = described_class.find(child)
        expect(config).not_to be_nil
        expect(config.registry.channels.length).to eq(1)
      end
    end

    it 'prefers .metanorma.yml over .metanorma.yaml' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.metanorma.yml'), "channels:\n  - public/yml\n")
        File.write(File.join(dir, '.metanorma.yaml'), "channels:\n  - public/yaml\n")
        config = described_class.find(dir)
        expect(config.registry.channels[0].category).to eq('yml')
      end
    end

    it 'returns nil when no config found' do
      Dir.mktmpdir do |dir|
        config = described_class.find(dir)
        expect(config).to be_nil
      end
    end
  end
end
