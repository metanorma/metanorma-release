# frozen_string_literal: true

RSpec.describe Metanorma::Release::EditionSlug do
  let(:strategy) { described_class.new }

  def build_pub(identifier: "CC 18011", edition: "1", stage: "60")
    Metanorma::Release::Publication.new(
      identifier: identifier, slug: Metanorma::Release::Publication.slug_from_identifier(identifier),
      title: "Test", edition: edition, stage: stage,
      doctype: "standard", revdate: nil,
      files: [], channels: [], source: nil
    )
  end

  it "computes edition tag" do
    result = strategy.compute_tag(build_pub)
    expect(result[:tag]).to eq("cc-18011/ed1")
    expect(result[:pre_release]).to be false
  end

  it "detects draft stage as pre-release" do
    result = strategy.compute_tag(build_pub(stage: "30"))
    expect(result[:pre_release]).to be true
  end

  it "computes asset name" do
    expect(strategy.compute_asset_name(build_pub)).to eq("cc-18011-ed1.zip")
  end
end

RSpec.describe Metanorma::Release::VersionSlug do
  let(:strategy) { described_class.new }

  def build_pub(identifier: "IHO S-101", edition: "5")
    Metanorma::Release::Publication.new(
      identifier: identifier, slug: Metanorma::Release::Publication.slug_from_identifier(identifier),
      title: "Test", edition: edition, stage: "60",
      doctype: "standard", revdate: nil,
      files: [], channels: [], source: nil
    )
  end

  it "computes version tag" do
    result = strategy.compute_tag(build_pub)
    expect(result[:tag]).to eq("iho-s-101/v5")
  end

  it "computes asset name" do
    expect(strategy.compute_asset_name(build_pub)).to eq("iho-s-101-v5.zip")
  end
end

RSpec.describe Metanorma::Release::InternetDraftSlug do
  let(:strategy) { described_class.new }

  def build_pub(identifier: "draft-ietf-netconf-123")
    Metanorma::Release::Publication.new(
      identifier: identifier,
      slug: Metanorma::Release::Publication.slug_from_identifier(identifier),
      title: "Test", edition: "1", stage: "40",
      doctype: "standard", revdate: nil,
      files: [], channels: [], source: nil
    )
  end

  it "parses draft-ietf identifier" do
    result = strategy.compute_tag(build_pub(identifier: "draft-ietf-netconf-restconf-23"))
    expect(result[:tag]).to eq("id-netconf-restconf/23")
    expect(result[:pre_release]).to be true
  end

  it "falls back for non-matching identifier" do
    result = strategy.compute_tag(build_pub(identifier: "other-doc"))
    expect(result[:tag]).to eq("other-doc/draft")
  end

  it "uses identifier as asset name" do
    expect(strategy.compute_asset_name(build_pub)).to eq("draft-ietf-netconf-123.zip")
  end
end

RSpec.describe Metanorma::Release::SlugRegistry do
  describe ".default" do
    let(:registry) { described_class.default }

    it "resolves ietf to InternetDraftSlug" do
      expect(registry.resolve("ietf")).to be_a(Metanorma::Release::InternetDraftSlug)
    end

    it "resolves ieee to DraftSuffixSlug" do
      expect(registry.resolve("ieee")).to be_a(Metanorma::Release::DraftSuffixSlug)
    end

    it "defaults to EditionSlug" do
      expect(registry.resolve("unknown")).to be_a(Metanorma::Release::EditionSlug)
    end
  end

  describe ".from_config" do
    it "builds registry from config strategies" do
      config = Metanorma::Release::Config.from_yaml(<<~YAML)
        slug:
          default: version
          strategies:
            ietf: internet-draft
            ogc: version
      YAML
      registry = described_class.from_config(config)
      expect(registry.resolve("ietf")).to be_a(Metanorma::Release::InternetDraftSlug)
      expect(registry.resolve("ogc")).to be_a(Metanorma::Release::VersionSlug)
      expect(registry.resolve("unknown")).to be_a(Metanorma::Release::VersionSlug)
    end
  end
end
