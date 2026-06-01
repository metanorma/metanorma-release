# frozen_string_literal: true

require "json"

RSpec.describe Metanorma::Release::PublicationSerializer do
  let(:pub) do
    Metanorma::Release::Publication.new(
      identifier: "CC 18011:2018", slug: "cc-18011-2018",
      title: "Date and time", edition: "1", stage: "60",
      doctype: "standard", revdate: "2018-06-01",
      files: [], channels: ["public"], source: nil
    )
  end

  describe ".to_release_body" do
    it "wraps metadata in HTML comment" do
      body = described_class.to_release_body(pub)
      expect(body).to start_with("<!-- mn-release-metadata\n")
      expect(body).to end_with("\n-->")
    end

    it "contains valid JSON with metadata" do
      body = described_class.to_release_body(pub)
      json = body.match(/<!--\s*mn-release-metadata\s*\n(.*?)\n-->/m)[1]
      data = JSON.parse(json)
      expect(data["id"]).to eq("cc-18011-2018")
      expect(data["identifier"]).to eq("CC 18011:2018")
      expect(data["publisher"]).to eq("cc")
    end
  end

  describe ".from_release_body" do
    it "parses release body back to publication" do
      body = described_class.to_release_body(pub)
      parsed = described_class.from_release_body(body)
      expect(parsed.identifier).to eq("CC 18011:2018")
      expect(parsed.slug).to eq("cc-18011-2018")
      expect(parsed.edition).to eq("1")
    end

    it "returns nil for nil body" do
      expect(described_class.from_release_body(nil)).to be_nil
    end

    it "returns nil for empty body" do
      expect(described_class.from_release_body("")).to be_nil
    end

    it "returns nil for body without metadata comment" do
      expect(described_class.from_release_body("just some text")).to be_nil
    end
  end

  describe ".to_json" do
    it "produces valid JSON" do
      json = described_class.to_json(pub)
      data = JSON.parse(json)
      expect(data["id"]).to eq("cc-18011-2018")
    end
  end

  describe ".from_json" do
    it "parses JSON to publication" do
      json = described_class.to_json(pub)
      parsed = described_class.from_json(json)
      expect(parsed.identifier).to eq("CC 18011:2018")
    end

    it "raises on missing id" do
      expect do
        described_class.from_json('{"title":"x"}')
      end.to raise_error(ArgumentError)
    end

    it "raises on missing title" do
      expect do
        described_class.from_json('{"id":"x"}')
      end.to raise_error(ArgumentError)
    end
  end

  describe "round-trip" do
    it "preserves metadata through to_release_body → from_release_body" do
      body = described_class.to_release_body(pub)
      parsed = described_class.from_release_body(body)
      expect(parsed.identifier).to eq(pub.identifier)
      expect(parsed.title).to eq(pub.title)
      expect(parsed.edition).to eq(pub.edition)
      expect(parsed.stage).to eq(pub.stage)
      expect(parsed.channels).to eq(pub.channels)
    end
  end
end
