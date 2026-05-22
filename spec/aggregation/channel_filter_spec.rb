# frozen_string_literal: true

RSpec.describe Metanorma::Release::MetadataFilter do
  describe "#matches?" do
    it "matches everything with empty filters" do
      filter = described_class.new
      expect(filter.matches?({ "channels" => ["public"] })).to be true
    end

    it "matches exact channel" do
      filter = described_class.new(channels: ["public"])
      expect(filter.matches?({ "channels" => ["public"] })).to be true
    end

    it "does not match different channels" do
      filter = described_class.new(channels: ["members"])
      expect(filter.matches?({ "channels" => ["public"] })).to be false
    end

    it "matches by channel prefix" do
      filter = described_class.new(channels: ["public"])
      expect(filter.matches?({ "channels" => ["public/standards"] })).to be true
    end
  end

  describe "#overlaps?" do
    it "returns true for empty filter" do
      filter = described_class.new
      expect(filter.overlaps?(["public"])).to be true
    end

    it "returns true for matching manifest" do
      filter = described_class.new(channels: ["public"])
      expect(filter.overlaps?(["public", "members"])).to be true
    end

    it "returns false for non-matching manifest" do
      filter = described_class.new(channels: ["members"])
      expect(filter.overlaps?(["public"])).to be false
    end
  end
end
