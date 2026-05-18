# frozen_string_literal: true

RSpec.describe Metanorma::Release::Config do
  describe ".from_yaml" do
    it "parses full config" do
      yaml = <<~YAML
        channels:
          - public
          - members
          - internal
        routing:
          default: [public]
          rules:
            - stage: ["20", "30"]
              channels: [internal]
            - stage: ["60"]
              channels: [public]
        slug:
          default: edition
          strategies:
            ietf: internet-draft
            ieee: draft-suffix
      YAML
      config = described_class.from_yaml(yaml)
      expect(config.channels).to eq(%w[public members internal])
      expect(config.routing_default).to eq(["public"])
      expect(config.routing_rules.length).to eq(2)
      expect(config.slug_default_strategy).to eq("edition")
      expect(config.slug_strategies).to eq({ "ietf" => "internet-draft",
                                             "ieee" => "draft-suffix" })
    end

    it "handles empty yaml" do
      config = described_class.from_yaml("")
      expect(config.channels).to eq([])
      expect(config.routing_default).to eq(["public"])
    end
  end

  describe ".defaults" do
    it "returns config with defaults" do
      config = described_class.defaults
      expect(config.channels).to eq([])
      expect(config.routing_default).to eq(["public"])
    end
  end

  describe "#resolve_channels" do
    let(:config) do
      described_class.from_yaml(<<~YAML)
        channels:
          - public
          - internal
        routing:
          default: [public]
          rules:
            - stage: ["20", "30"]
              channels: [internal]
            - stage: ["60"]
              channels: [public]
            - doctype: [report]
              channels: [public]
      YAML
    end

    def build_pub(stage: "60", doctype: "standard")
      Metanorma::Release::Publication.new(
        identifier: "CC 18011", slug: "cc-18011", title: "Test",
        edition: "1", stage: stage, doctype: doctype, revdate: nil,
        files: [], channels: [], source: nil
      )
    end

    it "matches stage 60 to public" do
      expect(config.resolve_channels(build_pub(stage: "60"))).to eq(["public"])
    end

    it "matches stage 30 to internal" do
      expect(config.resolve_channels(build_pub(stage: "30"))).to eq(["internal"])
    end

    it "matches doctype report to public" do
      expect(config.resolve_channels(build_pub(doctype: "report"))).to eq(["public"])
    end

    it "returns default when no rule matches" do
      expect(config.resolve_channels(build_pub(stage: "50",
                                               doctype: "standard"))).to eq(["public"])
    end

    it "defaults to public when no config" do
      default_config = described_class.defaults
      expect(default_config.resolve_channels(build_pub)).to eq(["public"])
    end

    it "falls back to org routing rules when no repo rules match" do
      org_config = Metanorma::Release::OrgConfig.from_yaml(<<~YAML)
        channels:
          - public/standards
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
      config = described_class.from_yaml("channels:\n  - public\n", org_config: org_config)
      expect(config.resolve_channels(build_pub(stage: "60"))).to eq(["public/standards"])
    end

    it "falls back to org default when no rules match at any level" do
      org_config = Metanorma::Release::OrgConfig.from_yaml(<<~YAML)
        channels:
          - public/standards
        defaults:
          routing:
            default:
              - public/standards
      YAML
      config = described_class.from_yaml("channels:\n  - public\n", org_config: org_config)
      expect(config.resolve_channels(build_pub(stage: "50"))).to eq(["public/standards"])
    end
  end

  describe ".from_file" do
    it "raises for missing file" do
      expect do
        described_class.from_file("/nonexistent.yml")
      end.to raise_error(ArgumentError)
    end

    it "reads from file" do
      dir = Dir.mktmpdir
      path = File.join(dir, "config.yml")
      File.write(path, "channels:\n  - public\n")
      config = described_class.from_file(path)
      expect(config.channels).to eq(["public"])
    ensure
      FileUtils.rm_rf(dir)
    end

    it "exposes org reference" do
      config = described_class.from_yaml("org: CalConnect/.metanorma\nchannels:\n  - public\n")
      expect(config.org).to eq("CalConnect/.metanorma")
    end
  end
end
