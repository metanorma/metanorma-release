# frozen_string_literal: true

RSpec.describe Metanorma::Release::DocumentFlattener do
  let(:flattener) { described_class.new(display_categories: []) }

  describe "#flatten" do
    it "maps id to slug" do
      doc = { "id" => "cc-18011", "title" => "Test", "stage" => "published",
              "channels" => [], "formats" => [], "files" => [] }
      result = flattener.flatten(doc)
      expect(result["slug"]).to eq("cc-18011")
    end

    it "defaults stage to published" do
      doc = { "id" => "x", "title" => "T" }
      result = flattener.flatten(doc)
      expect(result["stage"]).to eq("published")
    end

    it "adds format flags" do
      doc = { "id" => "x", "title" => "T", "formats" => %w[html pdf],
              "files" => [] }
      result = flattener.flatten(doc)
      expect(result["has_html"]).to be true
      expect(result["has_pdf"]).to be true
      expect(result["has_xml"]).to be false
    end

    it "adds file paths for each format" do
      doc = { "id" => "x", "title" => "T", "formats" => %w[html],
              "files" => [{ "format" => "html", "path" => "x/test.html",
                            "name" => "test.html" }] }
      result = flattener.flatten(doc)
      expect(result["html_path"]).to eq("x/test.html")
    end

    it "extracts date from source when no bib date" do
      doc = { "id" => "x", "title" => "T",
              "source" => { "releaseDate" => "2024-01-15T10:00:00Z" } }
      result = flattener.flatten(doc)
      expect(result["date"]).to eq("2024-01-15")
    end

    it "adds display category when doctype matches" do
      categories = [{ "name" => "Standards", "slug" => "standards",
                      "doctypes" => ["standard"] }]
      f = described_class.new(display_categories: categories)
      doc = { "id" => "x", "title" => "T", "doctype" => "standard" }
      result = f.flatten(doc)
      expect(result["display_category"]).to eq("Standards")
      expect(result["display_category_slug"]).to eq("standards")
    end

    it "extracts contributors from bibliographic data" do
      bib = {
        "contributor" => [
          { "person" => { "name" => { "completename" => { "content" => "John Doe" } } },
            "role" => [{ "type" => "author" }] },
          { "organization" => { "subdivision" => [{ "name" => { "content" => "TC 1" } }] } },
        ],
      }
      doc = { "id" => "x", "title" => "T", "bibliographic" => bib }
      result = flattener.flatten(doc)
      expect(result["authors"].length).to eq(1)
      expect(result["authors"].first["name"]).to eq("John Doe")
      expect(result["committee"]).to eq("TC 1")
    end
  end
end
