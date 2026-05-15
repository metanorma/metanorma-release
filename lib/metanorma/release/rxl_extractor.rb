# frozen_string_literal: true

begin
  require "nokogiri"
rescue LoadError
  raise LoadError, "The nokogiri gem is required for RxlExtractor. Add `gem 'nokogiri'` to your Gemfile."
end

module Metanorma
  module Release
    class RxlExtractor
      def initialize(fallback_flavor: nil)
        @fallback_flavor = fallback_flavor
      end

      def discover(output_dir)
        rxl_files = Dir.glob(File.join(output_dir, "**", "*.rxl"))
        rxl_files.filter_map do |path|
          begin
            extract(path)
          rescue StandardError => e
            warn "Warning: Skipping #{path}: #{e.message}"
            nil
          end
        end
      end

      def extract(rxl_path)
        raise ArgumentError, "RXL file not found: #{rxl_path}" unless File.exist?(rxl_path)

        content = File.read(rxl_path)
        doc = Nokogiri::XML(content, nil, "UTF-8", Nokogiri::XML::ParseOptions::STRICT)
        extract_from_xml(doc, rxl_path)
      rescue Nokogiri::XML::SyntaxError => e
        warn "Warning: Failed to parse RXL #{rxl_path}: #{e.message}"
        fallback_metadata(rxl_path)
      end

      private

      def extract_from_xml(xml, rxl_path)
        bibdata = xml.at_xpath("/bibdata") || xml.root
        raw_id = text_of(bibdata, "docidentifier") || derive_id_from_path(rxl_path)
        id = DocumentId.from_raw(raw_id)
        title = text_of(bibdata, "title") || ""
        edition = text_of(bibdata, "edition") || "1"
        stage_node = bibdata.at_xpath("status/stage")
        stage = if stage_node
                  DocumentStage.from_iso_stage(stage_node.text.to_i)
                else
                  DocumentStage.published
                end
        version = DocumentVersion.from(edition, stage)
        doctype = text_of(bibdata, "ext/doctype") || ""
        revdate = extract_revdate(bibdata)
        flavor = @fallback_flavor || detect_flavor(raw_id)
        output_dir = File.dirname(rxl_path)
        file_base_name = File.basename(rxl_path, ".rxl")
        formats = detect_formats(output_dir, file_base_name)
        document_type = DocumentType.from_identifier(raw_id)

        DocumentMetadata.new(
          id: id, title: title, version: version, doctype: doctype,
          document_type: document_type, flavor: flavor, revdate: revdate,
          source_path: derive_source_path(rxl_path), output_dir: output_dir,
          formats: formats, file_base_name: file_base_name
        )
      end

      def fallback_metadata(rxl_path)
        file_base_name = File.basename(rxl_path, ".rxl")
        id = DocumentId.from_raw(file_base_name)
        DocumentMetadata.new(
          id: id, title: "", version: DocumentVersion.published(edition: "0"),
          doctype: "", document_type: "standard", flavor: nil, revdate: nil,
          source_path: rxl_path, output_dir: File.dirname(rxl_path),
          formats: [], file_base_name: file_base_name
        )
      end

      def text_of(node, xpath)
        n = node.at_xpath(xpath)
        n&.text&.strip
      end

      def extract_revdate(bibdata)
        date_node = bibdata.at_xpath("date[@type='published']/on") ||
                    bibdata.at_xpath("date/on")
        date_node&.text&.strip
      end

      def detect_formats(output_dir, base_name)
        extensions = []
        %w[html pdf xml rxl doc].each do |ext|
          path = File.join(output_dir, "#{base_name}.#{ext}")
          extensions << ext if File.exist?(path)
        end
        extensions
      end

      def detect_flavor(raw_id)
        return nil if raw_id.nil?
        parts = raw_id.split(/\s|-/)
        parts.first&.downcase
      end

      def derive_id_from_path(rxl_path)
        File.basename(rxl_path, ".rxl")
      end

      def derive_source_path(rxl_path)
        rxl_path.sub(/\.rxl$/, ".adoc")
      end
    end
  end
end
