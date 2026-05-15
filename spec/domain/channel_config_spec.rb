# frozen_string_literal: true

RSpec.describe Metanorma::Release::ChannelConfig do
  let(:full_yaml) do
    <<~YAML
      channels:
        - public/standards
        - members/drafts
      defaults:
        visibility: public
        channels:
          - public/standards
    YAML
  end

  let(:minimal_yaml) do
    <<~YAML
      channels:
        - public/standards
    YAML
  end

  describe ".from_yaml" do
    it "parses full config with channels and defaults" do
      config = described_class.from_yaml(full_yaml)
      expect(config.registry.channels.length).to eq(2)
      expect(config.default_visibility).to eq("public")
      expect(config.default_channels.length).to eq(1)
      expect(config.default_channels[0]).to eql(build_channel("public/standards"))
    end

    it "uses sensible defaults when only channels specified" do
      config = described_class.from_yaml(minimal_yaml)
      expect(config.registry.channels.length).to eq(1)
      expect(config.default_visibility).to eq("public")
      expect(config.default_channels).to be_empty
    end

    it "raises on invalid YAML" do
      expect { described_class.from_yaml("not a hash") }.to raise_error(ArgumentError)
    end
  end

  describe ".from_file" do
    it "reads a YAML file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "config.yml")
        File.write(path, full_yaml)
        config = described_class.from_file(path)
        expect(config.registry.channels.length).to eq(2)
      end
    end

    it "reads channels.yml from a directory" do
      Dir.mktmpdir do |dir|
        subdir = File.join(dir, ".metanorma")
        Dir.mkdir(subdir)
        File.write(File.join(subdir, "channels.yml"), full_yaml)
        config = described_class.from_file(subdir)
        expect(config.registry.channels.length).to eq(2)
      end
    end

    it "raises when file not found" do
      expect { described_class.from_file("/nonexistent.yml") }.to raise_error(ArgumentError)
    end

    it "raises when directory has no channels.yml" do
      Dir.mktmpdir do |dir|
        expect { described_class.from_file(dir) }.to raise_error(ArgumentError)
      end
    end
  end

  describe ".empty" do
    it "returns permissive config" do
      config = described_class.empty
      expect(config.registry).to be_empty
      expect(config.default_visibility).to eq("public")
      expect(config.default_channels).to be_empty
      expect(config.registry.valid?(build_channel("anything/goes"))).to be true
    end
  end

  it "is frozen" do
    expect(described_class.from_yaml(full_yaml)).to be_frozen
  end
end
