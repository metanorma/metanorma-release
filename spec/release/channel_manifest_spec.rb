# frozen_string_literal: true

RSpec.describe Metanorma::Release::ChannelManifest do
  let(:manifests_dir) { File.join(__dir__, "../fixtures/manifests") }

  describe ".from_file" do
    it "parses minimal manifest" do
      m = described_class.from_file(File.join(manifests_dir, "minimal.yml"))
      expect(m).to be_explicit
      expect(m.all_channels.length).to be >= 1
    end

    it "parses full manifest" do
      m = described_class.from_file(File.join(manifests_dir, "full.yml"))
      expect(m.list_all.length).to eq(2)
    end

    it "raises for missing file" do
      expect { described_class.from_file("/nonexistent.yml") }.to raise_error(ArgumentError)
    end

    it "raises for path traversal" do
      expect { described_class.from_file(File.join(manifests_dir, "malicious.yml")) }
        .to raise_error(ArgumentError, /traversal/)
    end
  end

  describe ".all_public" do
    let(:manifest) { described_class.all_public }

    it "releases everything" do
      policy = manifest.resolve("anything")
      expect(policy).to be_release
    end

    it "is not explicit" do
      expect(manifest).not_to be_explicit
    end
  end

  describe ".all_private" do
    let(:manifest) { described_class.all_private }

    it "releases nothing" do
      policy = manifest.resolve("anything")
      expect(policy).not_to be_release
    end
  end

  describe "#resolve" do
    it "exact source match takes priority over pattern" do
      m = described_class.from_file(File.join(manifests_dir, "pattern_matching.yml"))
      policy = m.resolve({ "source_path" => "sources/cc-18011.adoc" })
      channel_strs = policy.channels.map(&:to_s)
      expect(channel_strs).to include("public/reports")
    end

    it "pattern match selects matching entry" do
      m = described_class.from_file(File.join(manifests_dir, "pattern_matching.yml"))
      policy = m.resolve({ "source_path" => "cc-12345.adoc" })
      channel_strs = policy.channels.map(&:to_s)
      expect(channel_strs).to include("public/standards")
    end

    it "unlisted document uses defaults" do
      m = described_class.from_file(File.join(manifests_dir, "minimal.yml"))
      policy = m.resolve({ "source_path" => "unknown.adoc" })
      expect(policy).to be_release
      expect(policy.channels.map(&:to_s)).to include("public/standards")
    end

    it "resolves stages from manifest entry" do
      m = described_class.from_file(File.join(manifests_dir, "full.yml"))
      policy = m.resolve({ "source_path" => "sources/cc-19060-draft.adoc" })
      expect(policy.stage_allow_list).to include("working-draft")
      expect(policy.stage_allow_list).to include("committee-draft")
    end

    it "nil stages allow all" do
      m = described_class.from_file(File.join(manifests_dir, "full.yml"))
      policy = m.resolve({ "source_path" => "sources/cc-19060.adoc" })
      expect(policy.stage_allow_list).to be_nil
    end
  end

  describe "#all_channels" do
    it "returns deduplicated channels" do
      m = described_class.from_file(File.join(manifests_dir, "full.yml"))
      channels = m.all_channels
      public_standards = channels.select { |c| c.to_s == "public/standards" }
      expect(public_standards.length).to eq(1)
    end
  end

  describe "#config_source" do
    it "returns nil when no config key in manifest" do
      m = described_class.from_file(File.join(manifests_dir, "minimal.yml"))
      expect(m.config_source).to be_nil
    end

    it "returns the config value from manifest" do
      yaml = <<~YAML
        config: local:/path/to/config.yml
        defaults:
          visibility: public
      YAML
      m = described_class.from_yaml(yaml)
      expect(m.config_source).to eq("local:/path/to/config.yml")
    end
  end
end
