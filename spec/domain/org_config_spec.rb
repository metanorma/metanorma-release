# frozen_string_literal: true

RSpec.describe Metanorma::Release::OrgConfig do
  describe ".parse_ref" do
    it "parses simple org reference" do
      ref = described_class.parse_ref("CalConnect/.metanorma")
      expect(ref.owner).to eq("CalConnect")
      expect(ref.repo).to eq(".metanorma")
      expect(ref.name).to be_nil
    end

    it "parses org reference with config name" do
      ref = described_class.parse_ref("CalConnect/.metanorma#working-groups")
      expect(ref.owner).to eq("CalConnect")
      expect(ref.repo).to eq(".metanorma")
      expect(ref.name).to eq("working-groups")
    end

    it "raises for invalid reference" do
      expect { described_class.parse_ref("nonsense") }.to raise_error(ArgumentError)
    end
  end

  describe ".remote_path" do
    it "returns default path when no config name" do
      ref = described_class.parse_ref("CalConnect/.metanorma")
      expect(described_class.remote_path(ref)).to eq(".metanorma/channels.yml")
    end

    it "returns named path when config name given" do
      ref = described_class.parse_ref("CalConnect/.metanorma#working-groups")
      expect(described_class.remote_path(ref)).to eq(".metanorma/working-groups.yml")
    end
  end

  describe ".from_yaml" do
    it "parses full org config" do
      yaml = <<~YAML
        channels:
          - public/standards
          - public/directives
          - members/drafts
          - internal/working
        defaults:
          routing:
            rules:
              - stage: ["60"]
                channels: [public/standards]
              - stage: ["20", "30", "40"]
                channels: [internal/working]
            default:
              - public/standards
      YAML
      config = described_class.from_yaml(yaml)
      expect(config.channels).to eq(%w[public/standards public/directives members/drafts internal/working])
      expect(config.routing_default).to eq(["public/standards"])
      expect(config.routing_rules.length).to eq(2)
    end

    it "handles empty yaml" do
      config = described_class.from_yaml("")
      expect(config.channels).to eq([])
      expect(config.routing_default).to eq([])
      expect(config.routing_rules).to eq([])
    end
  end

  describe ".defaults" do
    it "returns permissive config" do
      config = described_class.defaults
      expect(config.channels).to eq([])
      expect(config.routing_default).to eq([])
      expect(config.routing_rules).to eq([])
    end
  end

  describe ".from_file" do
    it "raises for missing file" do
      expect { described_class.from_file("/nonexistent.yml") }.to raise_error(ArgumentError)
    end

    it "reads from file" do
      dir = Dir.mktmpdir
      path = File.join(dir, "channels.yml")
      File.write(path, "channels:\n  - public/standards\n")
      config = described_class.from_file(path)
      expect(config.channels).to eq(["public/standards"])
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  describe "#valid_channel?" do
    let(:config) do
      described_class.from_yaml(<<~YAML)
        channels:
          - public/standards
          - public/directives
          - members/drafts
      YAML
    end

    it "accepts exact channel match" do
      expect(config.valid_channel?("public/standards")).to be true
    end

    it "accepts sub-channel of a defined channel" do
      expect(config.valid_channel?("public/standards/v2")).to be true
    end

    it "accepts parent prefix of a defined channel" do
      expect(config.valid_channel?("public")).to be true
    end

    it "rejects unrelated channel" do
      expect(config.valid_channel?("internal/secret")).to be false
    end

    it "accepts anything when no channels defined" do
      default_config = described_class.defaults
      expect(default_config.valid_channel?("anything")).to be true
    end
  end
end
