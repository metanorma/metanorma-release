# frozen_string_literal: true

RSpec.describe Metanorma::Release::ChannelRegistry do
  let(:yaml_with_channels) do
    <<~YAML
      channels:
        - public/standards
        - members/drafts
        - internal/working-drafts
    YAML
  end

  let(:yaml_with_hash_entries) do
    <<~YAML
      channels:
        - name: public/standards
        - name: members/drafts
    YAML
  end

  let(:yaml_empty_channels) do
    <<~YAML
      channels: []
    YAML
  end

  describe ".from_yaml" do
    it "parses string channel entries" do
      registry = described_class.from_yaml(yaml_with_channels)
      expect(registry.channels.length).to eq(3)
      expect(registry.channels[0]).to eql(build_channel("public/standards"))
      expect(registry.channels[1]).to eql(build_channel("members/drafts"))
      expect(registry.channels[2]).to eql(build_channel("internal/working-drafts"))
    end

    it "parses hash channel entries with name key" do
      registry = described_class.from_yaml(yaml_with_hash_entries)
      expect(registry.channels.length).to eq(2)
      expect(registry.channels[0]).to eql(build_channel("public/standards"))
    end

    it "returns empty registry for empty channel list" do
      registry = described_class.from_yaml(yaml_empty_channels)
      expect(registry).to be_empty
    end

    it "raises on invalid YAML" do
      expect { described_class.from_yaml("not a hash") }.to raise_error(ArgumentError)
    end
  end

  describe ".from_file" do
    it "reads and parses a YAML file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "channels.yml")
        File.write(path, yaml_with_channels)
        registry = described_class.from_file(path)
        expect(registry.channels.length).to eq(3)
      end
    end

    it "raises when file not found" do
      expect { described_class.from_file("/nonexistent.yml") }.to raise_error(ArgumentError)
    end
  end

  describe ".all_allowed" do
    it "returns an empty registry that accepts all channels" do
      registry = described_class.all_allowed
      expect(registry).to be_empty
      expect(registry.valid?(build_channel("public/anything"))).to be true
      expect(registry.valid?(build_channel("members/whatever"))).to be true
    end
  end

  describe "#valid?" do
    context "with specific channels" do
      let(:registry) { described_class.from_yaml(yaml_with_channels) }

      it "returns true for registered channels" do
        expect(registry.valid?(build_channel("public/standards"))).to be true
        expect(registry.valid?(build_channel("members/drafts"))).to be true
      end

      it "returns false for unregistered channels" do
        expect(registry.valid?(build_channel("public/reports"))).to be false
        expect(registry.valid?(build_channel("internal/secret"))).to be false
      end
    end

    context "with empty registry (all allowed)" do
      let(:registry) { described_class.all_allowed }

      it "returns true for any channel" do
        expect(registry.valid?(build_channel("public/anything"))).to be true
      end
    end
  end

  describe "#include?" do
    let(:registry) { described_class.from_yaml(yaml_with_channels) }

    it "accepts Channel objects" do
      expect(registry.include?(build_channel("public/standards"))).to be true
    end

    it "accepts strings" do
      expect(registry.include?("public/standards")).to be true
    end

    it "returns false for missing channels" do
      expect(registry.include?("public/missing")).to be false
    end
  end

  it "is frozen" do
    expect(described_class.from_yaml(yaml_with_channels)).to be_frozen
  end
end
