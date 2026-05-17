# frozen_string_literal: true

RSpec.describe Metanorma::Release::Publication do
  let(:sample_data) do
    {
      "version" => 1,
      "id" => "cc-18011",
      "title" => "Date and time — Explicit representation",
      "edition" => "1",
      "stage" => "published",
      "doctype" => "standard",
      "revdate" => "2018-06-01",
      "formats" => %w[html pdf xml rxl],
      "channels" => ["public/standards"],
      "publisher" => "cc",
    }
  end

  describe ".from_json" do
    it "parses valid JSON" do
      json = JSON.generate(sample_data)
      pub = described_class.from_json(json)
      expect(pub.slug).to eq("cc-18011")
      expect(pub.title).to eq("Date and time — Explicit representation")
    end

    it "raises on missing id" do
      data = sample_data.except("id")
      expect { described_class.from_json(JSON.generate(data)) }
        .to raise_error(ArgumentError, /id/)
    end

    it "raises on missing title" do
      data = sample_data.except("title")
      expect { described_class.from_json(JSON.generate(data)) }
        .to raise_error(ArgumentError, /title/)
    end
  end

  describe ".from_release_body" do
    let(:body) do
      "content-hash:abc123\n<!-- mn-release-metadata\n#{JSON.generate(sample_data)}\n-->"
    end

    it "extracts metadata from HTML comment" do
      pub = described_class.from_release_body(body)
      expect(pub).not_to be_nil
      expect(pub.slug).to eq("cc-18011")
    end

    it "returns nil when no metadata comment found" do
      expect(described_class.from_release_body("no metadata here")).to be_nil
    end

    it "returns nil for nil body" do
      expect(described_class.from_release_body(nil)).to be_nil
    end

    it "returns nil when JSON parse fails" do
      bad_body = "<!-- mn-release-metadata\n{invalid json}\n-->"
      expect(described_class.from_release_body(bad_body)).to be_nil
    end
  end

  describe "#to_release_body" do
    it "produces valid HTML comment" do
      pub = described_class.from_json(JSON.generate(sample_data))
      body = pub.to_release_body
      expect(body).to start_with("<!-- mn-release-metadata")
      expect(body).to end_with("-->")
    end
  end

  describe "round-trip" do
    it "preserves data through from_release_body → to_release_body" do
      pub = described_class.from_json(JSON.generate(sample_data))
      body = pub.to_release_body
      parsed = described_class.from_release_body(body)
      expect(parsed.slug).to eq(pub.slug)
      expect(parsed.title).to eq(pub.title)
      expect(parsed.edition).to eq(pub.edition)
      expect(parsed.stage).to eq(pub.stage)
      expect(parsed.channels).to eq(pub.channels)
    end
  end
end
