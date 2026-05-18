# frozen_string_literal: true

require "json"
require "yaml"
require "fileutils"

module Metanorma
  module Release
    class Site
      attr_reader :index, :output_dir

      def initialize(index:, output_dir:, data_dir: nil)
        @index = index
        @output_dir = output_dir
        @data_dir = data_dir
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
        doc_id = resolve_doc_id(bib, doc)
        stage = (doc["stage"] || "published").to_s.downcase
        doctype = extract_doctype(bib) || doc.fetch("doctype", "")
        formats = doc["formats"] || []
        {
          "slug" => doc["id"],
          "id" => doc_id,
          "title" => doc["title"].to_s,
          "abstract" => extract_abstract(bib),
          "stage" => stage,
          "doctype" => doctype,
          "edition" => doc["edition"],
          "date" => extract_date(doc),
          "channels" => doc["channels"] || [],
          "formats" => formats,
          "files" => doc["files"] || [],
          "has_html" => formats.include?("html"),
          "has_pdf" => formats.include?("pdf"),
          "has_xml" => formats.include?("xml"),
          "stage_css" => stage.gsub(/\s+/, "-"),
          "doctype_class" => "type-#{doctype.downcase}",
        }
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
        release_date = doc.dig("source", "releaseDate")
        return nil unless release_date

        release_date.to_s.split(/[T ]/).first
      end
    end
  end
end
