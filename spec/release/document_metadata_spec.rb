# frozen_string_literal: true

RSpec.describe Metanorma::Release::DocumentMetadata do
  let(:metadata) do
    described_class.new(
      id: Metanorma::Release::DocumentId.from_raw("CC 18011"),
      title: "Test Doc",
      version: Metanorma::Release::DocumentVersion.from("1", Metanorma::Release::DocumentStage.published),
      doctype: "standard",
      document_type: "standard",
      flavor: "cc",
      revdate: "2025-06-01",
      source_path: "sources/cc-18011.adoc",
      output_dir: "/tmp/test",
      formats: %w[html pdf],
      file_base_name: "cc-18011"
    )
  end

  it "is frozen" do
    expect(metadata).to be_frozen
  end

  describe "#[]" do
    it "returns source_path" do
      expect(metadata["source_path"]).to eq("sources/cc-18011.adoc")
    end

    it "returns id as a DocumentId" do
      expect(metadata["id"].to_s).to eq("cc-18011")
    end

    it "returns nil for unknown key" do
      expect(metadata["nonexistent"]).to be_nil
    end
  end
end
