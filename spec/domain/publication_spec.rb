# frozen_string_literal: true

RSpec.describe Metanorma::Release::Publication do
  describe ".slug_from_identifier" do
    it "normalizes CC 18011:2018 to cc-18011-2018" do
      expect(described_class.slug_from_identifier("CC 18011:2018")).to eq("cc-18011-2018")
    end

    it "handles multiple spaces" do
      expect(described_class.slug_from_identifier("CC  18011")).to eq("cc-18011")
    end

    it "handles multiple colons" do
      expect(described_class.slug_from_identifier("CC::18011")).to eq("cc-18011")
    end

    it "lowercases" do
      expect(described_class.slug_from_identifier("ISO 8601")).to eq("iso-8601")
    end

    it "removes trailing dashes and dots" do
      expect(described_class.slug_from_identifier("CC 18011.")).to eq("cc-18011")
    end
  end

  describe ".publisher_from_identifier" do
    it "extracts first word as publisher" do
      expect(described_class.publisher_from_identifier("CC 18011:2018")).to eq("cc")
    end

    it "returns nil for nil" do
      expect(described_class.publisher_from_identifier(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.publisher_from_identifier("")).to be_nil
    end

    it "handles hyphenated identifiers" do
      expect(described_class.publisher_from_identifier("draft-ietf-some-01")).to eq("draft")
    end
  end

  describe "construction" do
    let(:pub) do
      described_class.new(
        identifier: "CC 18011:2018", slug: "cc-18011-2018",
        title: "Date and time", edition: "1", stage: "60",
        doctype: "standard", revdate: "2018-06-01",
        files: [], channels: ["public"], source: nil
      )
    end

    it "exposes all attributes" do
      expect(pub.identifier).to eq("CC 18011:2018")
      expect(pub.slug).to eq("cc-18011-2018")
      expect(pub.title).to eq("Date and time")
      expect(pub.edition).to eq("1")
      expect(pub.stage).to eq("60")
      expect(pub.doctype).to eq("standard")
      expect(pub.revdate).to eq("2018-06-01")
      expect(pub.channels).to eq(["public"])
      expect(pub.source).to be_nil
    end

    it "is frozen" do
      expect(pub).to be_frozen
    end

    it "exposes formats from files" do
      files = [Metanorma::Release::PublicationFile.new(format: "html",
                                                       name: "test.html", path: "test.html")]
      pub_with_files = described_class.new(
        identifier: "CC 18011", slug: "cc-18011", title: "Test",
        edition: "1", stage: "60", doctype: "standard", revdate: nil,
        files: files, channels: [], source: nil
      )
      expect(pub_with_files.formats).to eq(["html"])
      expect(pub_with_files.file?("html")).to be true
      expect(pub_with_files.file?("pdf")).to be false
    end
  end

  describe "#to_h" do
    it "serializes to hash" do
      files = [Metanorma::Release::PublicationFile.new(format: "pdf",
                                                       name: "test.pdf", path: "test.pdf")]
      pub = described_class.new(
        identifier: "CC 18011", slug: "cc-18011", title: "Test",
        edition: "1", stage: "60", doctype: "standard", revdate: "2024-01-01",
        files: files, channels: ["public"], source: nil
      )
      h = pub.to_h
      expect(h["id"]).to eq("cc-18011")
      expect(h["identifier"]).to eq("CC 18011")
      expect(h["channels"]).to eq(["public"])
      expect(h["files"].length).to eq(1)
      expect(h["files"][0]["format"]).to eq("pdf")
    end

    it "includes source when present" do
      source = Metanorma::Release::PublicationSource.new(
        owner: "CC", repo: "test", tag: "v1",
        url: "https://example.com", date: "2024-01-01"
      )
      pub = described_class.new(
        identifier: "CC 18011", slug: "cc-18011", title: "Test",
        edition: "1", stage: "60", doctype: "standard", revdate: nil,
        files: [], channels: [], source: source
      )
      expect(pub.to_h["source"]["owner"]).to eq("CC")
      expect(pub.to_h["source"]["repo"]).to eq("test")
    end
  end

  describe "#with_channels" do
    it "returns a new Publication with updated channels" do
      pub = described_class.new(
        identifier: "CC 18011", slug: "cc-18011", title: "Test",
        edition: "1", stage: "60", doctype: "standard", revdate: nil,
        files: [], channels: ["public"], source: nil
      )
      updated = pub.with_channels(%w[members])
      expect(updated.channels).to eq(%w[members])
      expect(pub.channels).to eq(["public"]) # original unchanged
    end
  end

  describe "equality" do
    it "equals by identifier, edition, stage" do
      a = described_class.new(
        identifier: "CC 18011", slug: "cc-18011", title: "A",
        edition: "1", stage: "60", doctype: "standard", revdate: nil,
        files: [], channels: [], source: nil
      )
      b = described_class.new(
        identifier: "CC 18011", slug: "cc-18011", title: "B",
        edition: "1", stage: "60", doctype: "standard", revdate: nil,
        files: [], channels: [], source: nil
      )
      expect(a).to eql(b)
    end

    it "differs by edition" do
      a = described_class.new(
        identifier: "CC 18011", slug: "cc-18011", title: "A",
        edition: "1", stage: "60", doctype: "standard", revdate: nil,
        files: [], channels: [], source: nil
      )
      b = described_class.new(
        identifier: "CC 18011", slug: "cc-18011", title: "A",
        edition: "2", stage: "60", doctype: "standard", revdate: nil,
        files: [], channels: [], source: nil
      )
      expect(a).not_to eql(b)
    end
  end
end

RSpec.describe Metanorma::Release::PublicationFile do
  it "exposes format, name, path" do
    f = described_class.new(format: "html", name: "test.html",
                            path: "out/test.html")
    expect(f.format).to eq("html")
    expect(f.name).to eq("test.html")
    expect(f.path).to eq("out/test.html")
  end

  it "is frozen" do
    expect(described_class.new(format: "html", name: "t",
                               path: "t")).to be_frozen
  end

  it "serializes to hash" do
    f = described_class.new(format: "pdf", name: "doc.pdf", path: "doc/doc.pdf")
    expect(f.to_h).to eq({ "format" => "pdf", "name" => "doc.pdf",
                           "path" => "doc/doc.pdf" })
  end
end

RSpec.describe Metanorma::Release::PublicationSource do
  it "computes repo_key" do
    s = described_class.new(owner: "CC", repo: "test-repo", tag: "v1",
                            url: "http://x", date: "2024-01-01")
    expect(s.repo_key).to eq("CC/test-repo")
  end

  it "serializes to hash" do
    s = described_class.new(owner: "CC", repo: "test", tag: "v1",
                            url: "http://x", date: "2024-01-01")
    h = s.to_h
    expect(h["owner"]).to eq("CC")
    expect(h["releaseUrl"]).to eq("http://x")
  end
end
