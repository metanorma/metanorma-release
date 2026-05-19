# frozen_string_literal: true

require "json"
require "yaml"
require "fileutils"

module Metanorma
  module Release
    class Site
      attr_reader :index, :output_dir

      def initialize(index:, output_dir:, data_dir: nil, org_config: nil)
        @index = index
        @output_dir = output_dir
        @data_dir = data_dir
        @org_config = org_config
      end

      def write!
        FileUtils.mkdir_p(output_dir)
        index.write(File.join(output_dir, "index.json"))
      end

      def enrich!
        return if index.empty?

        documents = enrich_documents
        write_relaton_index(documents)
        write_data_file(documents) if @data_dir
      end

      def package!(zip_path: nil)
        require "zip"

        path = zip_path || "#{output_dir}.zip"
        Zip::File.open(path, Zip::File::CREATE) do |zipfile|
          Dir.glob("#{output_dir}/**/*").each do |file|
            next if File.directory?(file)

            entry_name = file.sub("#{File.dirname(output_dir)}/", "")
            zipfile.add(entry_name, file)
          end
        end
        path
      end

      private

      def enrich_documents
        index.publications.map do |pub|
          enrich_publication(pub)
        rescue StandardError => e
          warn "  Skip #{pub.identifier}: #{e.message}"
          pub.to_h
        end
      end

      def enrich_publication(pub)
        rxl_file = pub.files.find { |f| f.format == "rxl" }
        return pub.to_h unless rxl_file

        rxl_path = File.join(output_dir, rxl_file.path)
        return pub.to_h unless File.exist?(rxl_path)

        bib = Relaton::Bib::Item.from_xml(File.read(rxl_path))
        pub.to_h.merge("bibliographic" => bib.to_h)
      end

      def write_relaton_index(documents)
        dest = File.join(output_dir, "relaton")
        FileUtils.mkdir_p(dest)
        index_data = { "root" => { "title" => "Document Registry",
                                   "items" => documents.compact } }
        File.write(File.join(dest, "index.json"),
                   JSON.pretty_generate(index_data))
        File.write(File.join(dest, "index.yaml"), YAML.dump(index_data))
      end

      def write_data_file(documents)
        FileUtils.mkdir_p(@data_dir)
        items = documents.compact.map { |doc| flatten_for_site(doc) }
        File.write(File.join(@data_dir, "documents.json"),
                   JSON.pretty_generate({ "items" => items }))
      end

      def flatten_for_site(doc)
        bib = doc["bibliographic"] || {}
        doctype = extract_doctype(bib) || doc.fetch("doctype", "")
        formats = doc["formats"] || []
        base = {
          "slug" => doc["id"],
          "id" => resolve_doc_id(bib, doc),
          "title" => doc["title"].to_s,
          "abstract" => extract_abstract(bib),
          "stage" => (doc["stage"] || "published").to_s.downcase,
          "doctype" => doctype,
          "edition" => doc["edition"],
          "date" => extract_date(doc),
          "channels" => doc["channels"] || [],
          "formats" => formats,
          "files" => doc["files"] || [],
        }
        add_format_flags(base, formats)
        add_display_category(base, doctype)
        base
      end

      def add_format_flags(hash, formats)
        hash["has_html"] = formats.include?("html")
        hash["has_pdf"] = formats.include?("pdf")
        hash["has_xml"] = formats.include?("xml")
      end

      def add_display_category(hash, doctype)
        cat = resolve_display_category(doctype)
        hash["stage_css"] = hash["stage"].gsub(/\s+/, "-")
        hash["doctype_class"] = "type-#{doctype.downcase}"
        hash["display_category"] = cat&.fetch("name", nil)
        hash["display_category_slug"] = cat&.fetch("slug", nil)
      end

      def resolve_doc_id(bib, doc)
        extract_primary_id(bib) || doc["identifier"] || doc["id"]
      end

      def extract_primary_id(bib)
        ids = bib["docidentifier"]
        return nil unless ids&.any?

        primary = ids.find { |di| di["primary"] == true } || ids.first
        primary["content"]
      end

      def extract_doctype(bib)
        bib.dig("ext", "doctype", "content")
      end

      def extract_abstract(bib)
        abstracts = bib["abstract"]
        return nil unless abstracts&.any?

        abstracts.first["content"]
      end

      def extract_date(doc)
        bib_date = extract_bib_date(doc["bibliographic"])
        return bib_date if bib_date

        release_date = doc.dig("source", "releaseDate")
        return nil unless release_date

        release_date.to_s.split(/[T ]/).first
      end

      def extract_bib_date(bib)
        return nil unless bib

        dates = bib["date"]
        return nil if dates.nil? || dates.empty?

        published = dates.find { |d| d["type"] == "published" }
        entry = published || dates.first
        at = entry["at"]
        at ? at.to_s.split(/[T ]/).first : nil
      end

      def resolve_display_category(doctype)
        return nil unless @org_config

        @org_config.display_category_for(doctype)
      end
    end
  end
end
