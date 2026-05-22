# frozen_string_literal: true

RSpec.describe Metanorma::Release::Config do
  describe ".from_yaml" do
    it "parses full config" do
      yaml = <<~YAML
        channels:
          - public
          - members
          - internal
        slug:
          default: edition
          strategies:
            ietf: internet-draft
            ieee: draft-suffix
      YAML
      config = described_class.from_yaml(yaml)
      expect(config.channels).to eq(%w[public members internal])
      expect(config.slug_default_strategy).to eq("edition")
      expect(config.slug_strategies).to eq({ "ietf" => "internet-draft",
                                             "ieee" => "draft-suffix" })
    end

    it "handles empty yaml" do
      config = described_class.from_yaml("")
      expect(config.channels).to eq([])
    end
  end

  describe ".defaults" do
    it "returns config with defaults" do
      config = described_class.defaults
      expect(config.channels).to eq([])
      expect(config.document_entries).to eq([])
    end
  end

  describe "#document_entries" do
    it "returns DocumentEntry value objects with all matching criteria" do
      config = described_class.from_yaml(<<~YAML)
        documents:
          - pattern: "cc-s-*"
            channels: [public/standards]
          - stage: ["50"]
            channels: [members/drafts]
          - channels: [public]
      YAML
      entries = config.document_entries
      expect(entries.length).to eq(3)
      expect(entries[0]).to be_a(Metanorma::Release::DocumentEntry)
      expect(entries[0].pattern).to eq("cc-s-*")
      expect(entries[0].stages).to eq([])
      expect(entries[1].pattern).to be_nil
      expect(entries[1].stages).to eq(["50"])
      expect(entries[1].channels).to eq(["members/drafts"])
      expect(entries[2].pattern).to be_nil
      expect(entries[2].stages).to eq([])
      expect(entries[2].channels).to eq(["public"])
    end
  end

  describe "#resolve_channels" do
    def build_pub(slug: "cc-18011", stage: "60", doctype: "standard")
      Metanorma::Release::Publication.new(
        identifier: slug, slug: slug, title: "Test",
        edition: "1", stage: stage, doctype: doctype, revdate: nil,
        files: [], channels: [], source: nil
      )
    end

    it "matches document pattern against slug" do
      config = described_class.from_yaml(<<~YAML)
        documents:
          - pattern: "cc-s-*"
            channels: [public/standards]
          - pattern: "cc-r-*"
            channels: [public/reports]
      YAML
      expect(config.resolve_channels(build_pub(slug: "cc-s-18011"))).to eq(["public/standards"])
      expect(config.resolve_channels(build_pub(slug: "cc-r-001"))).to eq(["public/reports"])
    end

    it "matches stage only" do
      config = described_class.from_yaml(<<~YAML)
        documents:
          - stage: ["60"]
            channels: [published]
          - stage: ["50"]
            channels: [drafts]
          - channels: [public]
      YAML
      expect(config.resolve_channels(build_pub(stage: "60"))).to eq(["published"])
      expect(config.resolve_channels(build_pub(stage: "50"))).to eq(["drafts"])
    end

    it "matches doctype only" do
      config = described_class.from_yaml(<<~YAML)
        documents:
          - doctype: [report]
            channels: [public/reports]
          - channels: [public/standards]
      YAML
      expect(config.resolve_channels(build_pub(doctype: "report"))).to eq(["public/reports"])
      expect(config.resolve_channels(build_pub(doctype: "standard"))).to eq(["public/standards"])
    end

    it "matches pattern + stage combined" do
      config = described_class.from_yaml(<<~YAML)
        documents:
          - pattern: "cc-*"
            stage: ["60"]
            channels: [public/standards]
          - pattern: "cc-*"
            stage: ["50"]
            channels: [members/drafts]
          - channels: [public]
      YAML
      expect(config.resolve_channels(build_pub(slug: "cc-18011", stage: "60"))).to eq(["public/standards"])
      expect(config.resolve_channels(build_pub(slug: "cc-18011", stage: "50"))).to eq(["members/drafts"])
    end

    it "matches pattern + doctype combined" do
      config = described_class.from_yaml(<<~YAML)
        documents:
          - pattern: "cc-s-*"
            doctype: [standard]
            channels: [public/standards]
          - pattern: "cc-s-*"
            doctype: [amendment]
            channels: [public/amendments]
      YAML
      expect(config.resolve_channels(build_pub(slug: "cc-s-18011", doctype: "standard"))).to eq(["public/standards"])
      expect(config.resolve_channels(build_pub(slug: "cc-s-18011", doctype: "amendment"))).to eq(["public/amendments"])
    end

    it "first match wins" do
      config = described_class.from_yaml(<<~YAML)
        documents:
          - pattern: "cc-*"
            channels: [first-match]
          - pattern: "cc-18011"
            channels: [second-match]
      YAML
      expect(config.resolve_channels(build_pub(slug: "cc-18011"))).to eq(["first-match"])
    end

    it "catch-all entry matches everything" do
      config = described_class.from_yaml(<<~YAML)
        documents:
          - pattern: "iso-*"
            channels: [public/standards]
          - channels: [public]
      YAML
      expect(config.resolve_channels(build_pub(slug: "cc-18011"))).to eq(["public"])
    end

    it "falls back to public when no documents defined" do
      default_config = described_class.defaults
      expect(default_config.resolve_channels(build_pub)).to eq(["public"])
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
  end
end

RSpec.describe Metanorma::Release::DocumentEntry do
  def pub(slug: "cc-18011", stage: "60", doctype: "standard", source_path: nil)
    instance_double("Publication", slug: slug, stage: stage, doctype: doctype, source_path: source_path)
  end

  it "matches pattern only" do
    entry = described_class.new("pattern" => "cc-s-*", "channels" => ["public/standards"])
    expect(entry.matches?(pub(slug: "cc-s-18011"))).to be true
    expect(entry.matches?(pub(slug: "cc-r-001"))).to be false
  end

  it "matches stage only" do
    entry = described_class.new("stage" => ["60"], "channels" => ["published"])
    expect(entry.matches?(pub(stage: "60"))).to be true
    expect(entry.matches?(pub(stage: "30"))).to be false
  end

  it "matches doctype only" do
    entry = described_class.new("doctype" => ["report"], "channels" => ["reports"])
    expect(entry.matches?(pub(doctype: "report"))).to be true
    expect(entry.matches?(pub(doctype: "standard"))).to be false
  end

  it "matches source only" do
    entry = described_class.new("source" => "doc.adoc", "channels" => ["public"])
    expect(entry.matches?(pub(source_path: "output/doc.adoc"))).to be true
    expect(entry.matches?(pub(source_path: "other.adoc"))).to be false
  end

  it "matches all criteria combined" do
    entry = described_class.new("pattern" => "cc-*", "stage" => ["60"], "doctype" => ["standard"], "channels" => ["public/standards"])
    expect(entry.matches?(pub(slug: "cc-18011", stage: "60", doctype: "standard"))).to be true
    expect(entry.matches?(pub(slug: "cc-18011", stage: "50", doctype: "standard"))).to be false
    expect(entry.matches?(pub(slug: "cc-18011", stage: "60", doctype: "report"))).to be false
    expect(entry.matches?(pub(slug: "iso-18011", stage: "60", doctype: "standard"))).to be false
  end

  it "catch-all matches everything" do
    entry = described_class.new("channels" => ["public"])
    expect(entry.matches?(pub)).to be true
  end

  it "returns false for empty channels" do
    entry = described_class.new("pattern" => "cc-*")
    expect(entry.matches?(pub)).to be false
  end

  it "returns false when pattern doesn't match" do
    entry = described_class.new("pattern" => "iso-*", "channels" => ["public"])
    expect(entry.matches?(pub(slug: "cc-18011"))).to be false
  end
end

RSpec.describe Metanorma::Release::ChannelResolver do
  def build_pub(slug: "cc-18011", stage: "60", doctype: "standard")
    Metanorma::Release::Publication.new(
      identifier: slug, slug: slug, title: "Test",
      edition: "1", stage: stage, doctype: doctype, revdate: nil,
      files: [], channels: [], source: nil
    )
  end

  it "returns first matching entry's channels" do
    config = Metanorma::Release::Config.from_yaml(<<~YAML)
      documents:
        - pattern: "cc-*"
          channels: [public/standards]
        - channels: [public]
    YAML
    expect(described_class.resolve(build_pub(slug: "cc-18011"), config)).to eq(["public/standards"])
  end

  it "falls through to catch-all" do
    config = Metanorma::Release::Config.from_yaml(<<~YAML)
      documents:
        - pattern: "iso-*"
          channels: [public/standards]
        - channels: [public]
    YAML
    expect(described_class.resolve(build_pub(slug: "cc-18011"), config)).to eq(["public"])
  end

  it "returns public fallback when no documents" do
    config = Metanorma::Release::Config.defaults
    expect(described_class.resolve(build_pub, config)).to eq(["public"])
  end
end
