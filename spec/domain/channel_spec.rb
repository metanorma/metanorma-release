# frozen_string_literal: true

RSpec.describe Metanorma::Release::Channel do
  describe ".parse" do
    it "parses public/standards" do
      ch = described_class.parse("public/standards")
      expect(ch.audience).to eq("public")
      expect(ch.category).to eq("standards")
    end

    it "parses members/drafts" do
      ch = described_class.parse("members/drafts")
      expect(ch.audience).to eq("members")
      expect(ch.category).to eq("drafts")
    end

    it "parses internal/working-drafts" do
      ch = described_class.parse("internal/working-drafts")
      expect(ch.audience).to eq("internal")
      expect(ch.category).to eq("working-drafts")
    end

    it "defaults to public audience when no prefix" do
      ch = described_class.parse("standards")
      expect(ch.audience).to eq("public")
      expect(ch.category).to eq("standards")
    end

    it "defaults category to 'default' for bare audience" do
      ch = described_class.parse("public")
      expect(ch.category).to eq("default")
    end
  end

  describe "factory methods" do
    it ".public creates public channel" do
      ch = described_class.public("standards")
      expect(ch.audience).to eq("public")
      expect(ch.category).to eq("standards")
    end

    it ".members creates members channel" do
      ch = described_class.members("drafts")
      expect(ch.audience).to eq("members")
      expect(ch.category).to eq("drafts")
    end

    it ".internal creates internal channel" do
      ch = described_class.internal("working-drafts")
      expect(ch.audience).to eq("internal")
      expect(ch.category).to eq("working-drafts")
    end
  end

  describe "#to_s" do
    it "always includes audience prefix" do
      ch = described_class.public("standards")
      expect(ch.to_s).to eq("public/standards")
    end
  end

  describe "predicates" do
    it "#public? is true for public audience" do
      expect(described_class.public("x")).to be_public
    end

    it "#members? is true for members audience" do
      expect(described_class.members("x")).to be_members
    end
  end

  describe "#matches?" do
    let(:channel) { described_class.parse("public/standards") }

    it "matches when filter contains same channel as strings" do
      expect(channel.matches?(["public/standards"])).to be true
    end

    it "matches when filter contains same channel as Channel objects" do
      expect(channel.matches?([described_class.parse("public/standards")])).to be true
    end

    it "does not match when filter has different channels" do
      expect(channel.matches?(["members/drafts"])).to be false
    end

    it "matches when any filter channel matches" do
      expect(channel.matches?(["members/drafts", "public/standards"])).to be true
    end

    it "does not match empty filter" do
      expect(channel.matches?([])).to be false
    end
  end

  describe "equality" do
    it "same audience and category is equal" do
      a = described_class.parse("public/standards")
      b = described_class.parse("public/standards")
      expect(a).to eql(b)
    end

    it "different category is not equal" do
      a = described_class.parse("public/standards")
      b = described_class.parse("public/reports")
      expect(a).not_to eql(b)
    end

    it "equal objects have same hash" do
      a = described_class.parse("public/standards")
      b = described_class.parse("public/standards")
      expect(a.hash).to eq(b.hash)
    end
  end

  it "is frozen" do
    expect(described_class.parse("public/standards")).to be_frozen
  end
end
