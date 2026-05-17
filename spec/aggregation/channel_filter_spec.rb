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

    it "matches exact stage" do
      filter = described_class.new(stages: ["60"])
      expect(filter.matches?({ "channels" => ["public"],
                               "stage" => "60" })).to be true
    end

    it "does not match different stage" do
      filter = described_class.new(stages: ["60"])
      expect(filter.matches?({ "channels" => ["public"],
                               "stage" => "30" })).to be false
    end

    it "requires both channel and stage to match when both filters set" do
      filter = described_class.new(channels: ["public"], stages: ["60"])
      expect(filter.matches?({ "channels" => ["public"],
                               "stage" => "60" })).to be true
      expect(filter.matches?({ "channels" => ["public"],
                               "stage" => "30" })).to be false
      expect(filter.matches?({ "channels" => ["members"],
                               "stage" => "60" })).to be false
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
