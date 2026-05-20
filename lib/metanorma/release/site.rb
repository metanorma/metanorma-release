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
          "bibliographic" => bib,
        }
        add_format_flags(base, formats)
        add_display_category(base, doctype)
        add_contributors(base, bib)
        base
      end

      def add_format_flags(hash, formats)
        hash["has_html"] = formats.include?("html")
        hash["has_pdf"] = formats.include?("pdf")
        hash["has_xml"] = formats.include?("xml")
        hash["has_rxl"] = formats.include?("rxl")
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

      def add_contributors(hash, bib)
        contribs = bib["contributor"] || []
        persons, committees = partition_contributors(contribs)
        hash["authors"] = persons
        hash["committee"] = committees.first
      end

      def partition_contributors(contribs)
        persons = contribs.filter_map { |c| parse_person(c) }
        committees = contribs.filter_map { |c| parse_committee(c) }
        [persons, committees]
      end

      def parse_person(contrib)
        return nil unless contrib["person"]

        name = extract_person_name(contrib["person"])
        return nil unless name

        role = (contrib["role"] || []).first&.fetch("type", nil)
        { "name" => name, "role" => role }
      end

      def parse_committee(contrib)
        return nil unless contrib["organization"]

        extract_org_subdivision(contrib["organization"])
      end

      def extract_person_name(person)
        n = person["name"] || {}
        complete = n["completename"]
        return complete["content"] if complete.is_a?(Hash) && complete["content"]
        return complete if complete.is_a?(String)

        surname = n["surname"]
        given = n["given"]
        given_str = given.is_a?(Hash) ? given["content"].to_s : given.to_s
        parts = [given_str, surname].compact
        parts.empty? ? nil : parts.join(" ")
      end

      def extract_org_subdivision(org)
        subs = org["subdivision"]
        return nil unless subs&.any?

        sd = subs.first
        sd_name = sd["name"]
        if sd_name.is_a?(Array)
          sd_name.first&.dig("content")
        elsif sd_name.is_a?(Hash)
          sd_name["content"]
        else
          sd_name.to_s
        end
      end
    end
  end
end
