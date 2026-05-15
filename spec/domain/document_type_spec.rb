# frozen_string_literal: true

RSpec.describe Metanorma::Release::DocumentType do
  describe ".from_identifier" do
    {
      "RFC 822"             => "ietf-rfc",
      "RFC 2119"            => "ietf-rfc",
      "draft-ietf-quic-34"  => "ietf-draft",
      "ISO 9001"            => "iso",
      "ISO/IEC 12345-1"     => "iso",
      "IEC 62304"           => "iec",
      "IEEE 802.3"          => "ieee",
      "ITU-T G.711"         => "itu",
      "BIPM SI Brochure"    => "bipm",
      "S-100"               => "iho",
      "18-061"              => "ogc",
      "OIML R 111"          => "oiml",
      "GE.1.2.3"            => "un",
      "csa-123"             => "csa",
      "AN 123"              => "pdfa",
      "BPG 456"             => "pdfa",
      "TN 789"              => "pdfa",
      "SU/123"              => "mpfa",
      "M3AAWG-001"          => "m3aawg",
      "Ribose Test"         => "ribose"
    }.each do |id, expected|
      it "detects #{expected} for '#{id}'" do
        expect(described_class.from_identifier(id)).to eq(expected)
      end
    end

    it "defaults to standard for unknown identifiers" do
      expect(described_class.from_identifier("something-random")).to eq("standard")
    end

    it "defaults to standard for empty string" do
      expect(described_class.from_identifier("")).to eq("standard")
    end

    it "defaults to standard for numeric-only" do
      expect(described_class.from_identifier("12345")).to eq("standard")
    end

    it "RFC takes priority over standard" do
      expect(described_class.from_identifier("RFC 822")).to eq("ietf-rfc")
    end
  end
end
