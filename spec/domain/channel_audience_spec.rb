# frozen_string_literal: true

RSpec.describe Metanorma::Release::ChannelAudience do
  describe ".from_string" do
    it "returns public for public" do
      expect(described_class.from_string("public")).to eq("public")
    end

    it "returns members for members" do
      expect(described_class.from_string("members")).to eq("members")
    end

    it "returns internal for internal" do
      expect(described_class.from_string("internal")).to eq("internal")
    end

    it "is case-insensitive" do
      expect(described_class.from_string("PUBLIC")).to eq("public")
    end

    it "raises on unknown value" do
      expect { described_class.from_string("unknown") }.to raise_error(ArgumentError, /Unknown audience/)
    end

    it "strips whitespace" do
      expect(described_class.from_string("  public  ")).to eq("public")
    end
  end

  describe ".values" do
    it "returns all three audiences" do
      expect(described_class.values).to eq(%w[public members internal])
    end
  end
end
