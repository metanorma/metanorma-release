# frozen_string_literal: true

RSpec.describe Metanorma::Release::Channel do
  describe ".new" do
    it "creates a channel from string" do
      ch = described_class.new("public")
      expect(ch.name).to eq("public")
    end

    it "strips whitespace" do
      ch = described_class.new("  public  ")
      expect(ch.name).to eq("public")
    end
  end

  describe ".parse" do
    it "parses a channel string" do
      ch = described_class.parse("public")
      expect(ch.name).to eq("public")
    end
  end

  describe ".parse_list" do
    it "parses array of strings" do
      channels = described_class.parse_list(%w[public members])
      expect(channels.map(&:name)).to eq(%w[public members])
    end

    it "returns empty for nil" do
      expect(described_class.parse_list(nil)).to eq([])
    end
  end

  describe "#to_s" do
    it "returns name" do
      ch = described_class.new("public")
      expect(ch.to_s).to eq("public")
    end
  end

  describe "#matches?" do
    let(:channel) { described_class.new("public") }

    it "matches when filter contains same channel as string" do
      expect(channel.matches?(["public"])).to be true
    end

    it "matches when filter contains same channel as Channel objects" do
      expect(channel.matches?([described_class.new("public")])).to be true
    end

    it "does not match when filter has different channels" do
      expect(channel.matches?(["members"])).to be false
    end

    it "matches when any filter channel matches" do
      expect(channel.matches?(%w[members public])).to be true
    end

    it "does not match empty filter" do
      expect(channel.matches?([])).to be false
    end
  end

  describe "equality" do
    it "same name is equal" do
      a = described_class.new("public")
      b = described_class.new("public")
      expect(a).to eql(b)
    end

    it "different name is not equal" do
      a = described_class.new("public")
      b = described_class.new("members")
      expect(a).not_to eql(b)
    end

    it "equal objects have same hash" do
      a = described_class.new("public")
      b = described_class.new("public")
      expect(a.hash).to eq(b.hash)
    end
  end

  it "is frozen" do
    expect(described_class.new("public")).to be_frozen
  end
end
