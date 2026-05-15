# frozen_string_literal: true

RSpec.describe Metanorma::Release::DocumentId do
  describe ".from_raw" do
    it "normalizes CC 18011" do
      id = described_class.from_raw("CC 18011")
      expect(id.to_s).to eq("cc-18011")
    end

    it "normalizes ISO/IEC 12345-1" do
      id = described_class.from_raw("ISO/IEC 12345-1")
      expect(id.to_s).to eq("iso-iec-12345-1")
    end

    it "normalizes RFC 822" do
      id = described_class.from_raw("RFC 822")
      expect(id.to_s).to eq("rfc-822")
    end

    it "normalizes draft-ietf-quic-34" do
      id = described_class.from_raw("draft-ietf-quic-34")
      expect(id.to_s).to eq("draft-ietf-quic-34")
    end

    it "strips leading/trailing dashes" do
      id = described_class.from_raw("--hello-world--")
      expect(id.to_s).to eq("hello-world")
    end

    it "collapses multiple non-alphanumeric runs into single dash" do
      id = described_class.from_raw("CC///18011///2018")
      expect(id.to_s).to eq("cc-18011-2018")
    end

    it "rejects empty string" do
      expect { described_class.from_raw("") }.to raise_error(ArgumentError)
    end

    it "rejects whitespace-only string" do
      expect { described_class.from_raw("   ") }.to raise_error(ArgumentError)
    end

    it "rejects all-non-alphanumeric identifier" do
      expect { described_class.from_raw("---") }.to raise_error(ArgumentError)
    end

    it "rejects slashes-only" do
      expect { described_class.from_raw("///") }.to raise_error(ArgumentError)
    end

    it "is frozen" do
      expect(described_class.from_raw("CC 18011")).to be_frozen
    end
  end

  describe ".from_normalized" do
    it "accepts already-normalized value" do
      id = described_class.from_normalized("cc-18011")
      expect(id.to_s).to eq("cc-18011")
    end

    it "rejects nil" do
      expect { described_class.from_normalized(nil) }.to raise_error(ArgumentError)
    end

    it "rejects empty string" do
      expect { described_class.from_normalized("") }.to raise_error(ArgumentError)
    end

    it "strips whitespace" do
      id = described_class.from_normalized("  cc-18011  ")
      expect(id.to_s).to eq("cc-18011")
    end
  end

  describe "#tag_prefix and #file_name" do
    let(:id) { described_class.from_raw("CC 18011") }

    it "returns normalized value for tag_prefix" do
      expect(id.tag_prefix).to eq("cc-18011")
    end

    it "returns normalized value for file_name" do
      expect(id.file_name).to eq("cc-18011")
    end
  end

  describe "equality" do
    it "same normalization is equal" do
      a = described_class.from_raw("CC 18011")
      b = described_class.from_raw("cc-18011")
      expect(a).to eql(b)
    end

    it "different normalization is not equal" do
      a = described_class.from_raw("CC 18011")
      b = described_class.from_raw("CC 18012")
      expect(a).not_to eql(b)
    end

    it "equal objects have same hash" do
      a = described_class.from_raw("CC 18011")
      b = described_class.from_raw("cc 18011")
      expect(a.hash).to eq(b.hash)
    end

    it "supports hash key usage" do
      h = { described_class.from_raw("CC 18011") => true }
      expect(h[described_class.from_raw("cc 18011")]).to be true
    end
  end
end
