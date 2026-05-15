# frozen_string_literal: true

RSpec.describe Metanorma::Release::DocumentStage do
  describe ".from_status" do
    it "normalizes Published" do
      expect(described_class.from_status("Published").to_s).to eq("published")
    end

    it "normalizes WORKING DRAFT" do
      expect(described_class.from_status("WORKING DRAFT").to_s).to eq("working-draft")
    end

    it "normalizes committee-draft" do
      expect(described_class.from_status("committee-draft").to_s).to eq("committee-draft")
    end

    it "normalizes In Force" do
      expect(described_class.from_status("In Force").to_s).to eq("in-force")
    end

    it "rejects empty string" do
      expect { described_class.from_status("") }.to raise_error(ArgumentError)
    end

    it "rejects nil" do
      expect { described_class.from_status(nil) }.to raise_error(ArgumentError)
    end
  end

  describe ".from_iso_stage" do
    {
      20 => "working-draft",
      30 => "committee-draft",
      40 => "draft-standard",
      50 => "final-draft",
      60 => "published",
      95 => "withdrawn"
    }.each do |stage, expected|
      it "maps stage #{stage} to #{expected}" do
        expect(described_class.from_iso_stage(stage).to_s).to eq(expected)
      end
    end

    it "defaults to working-draft for unknown stage" do
      expect(described_class.from_iso_stage(37).to_s).to eq("working-draft")
    end
  end

  describe ".published" do
    it "creates published stage" do
      expect(described_class.published.to_s).to eq("published")
    end
  end

  describe ".working_draft" do
    it "creates working-draft stage" do
      expect(described_class.working_draft.to_s).to eq("working-draft")
    end
  end

  describe "#published?" do
    it "is true for published" do
      expect(described_class.from_status("published")).to be_published
    end

    it "is true for in-force" do
      expect(described_class.from_status("in-force")).to be_published
    end

    it "is true for approved" do
      expect(described_class.from_status("approved")).to be_published
    end

    it "is true for standard" do
      expect(described_class.from_status("standard")).to be_published
    end

    it "is false for working-draft" do
      expect(described_class.from_status("working-draft")).not_to be_published
    end
  end

  describe "#draft?" do
    it "is true for working-draft" do
      expect(described_class.from_status("working-draft")).to be_draft
    end

    it "is true for committee-draft" do
      expect(described_class.from_status("committee-draft")).to be_draft
    end

    it "is false for published" do
      expect(described_class.from_status("published")).not_to be_draft
    end

    it "is false for withdrawn" do
      expect(described_class.from_status("withdrawn")).not_to be_draft
    end
  end

  describe "#tag_suffix" do
    it "returns empty for published" do
      expect(described_class.published.tag_suffix).to eq("")
    end

    it "returns wd for working-draft" do
      expect(described_class.working_draft.tag_suffix).to eq("wd")
    end

    it "returns cd for committee-draft" do
      expect(described_class.from_status("committee-draft").tag_suffix).to eq("cd")
    end

    it "returns ds for draft-standard" do
      expect(described_class.from_status("draft-standard").tag_suffix).to eq("ds")
    end
  end

  describe "equality" do
    it "same name is equal" do
      a = described_class.from_status("working-draft")
      b = described_class.from_status("Working Draft")
      expect(a).to eql(b)
    end

    it "different name is not equal" do
      a = described_class.published
      b = described_class.working_draft
      expect(a).not_to eql(b)
    end

    it "equal objects have same hash" do
      a = described_class.from_status("published")
      b = described_class.from_status("Published")
      expect(a.hash).to eq(b.hash)
    end
  end

  it "is frozen" do
    expect(described_class.published).to be_frozen
  end
end
