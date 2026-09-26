# frozen_string_literal: true

module Metanorma
  module Release
    class RxlExtractor
      extend Extractor

      def self.discover(output_dir)
        require "relaton/bib"
        Dir.glob(File.join(output_dir, "**", "*.rxl")).filter_map do |path|
          from_rxl(path)
        rescue StandardError => e
          Metanorma::Release.logger.warn "Skipping #{path}: #{e.message}"
          nil
        end
      end

      def self.from_rxl(rxl_path)
        unless File.exist?(rxl_path)
          raise ArgumentError,
                "RXL file not found: #{rxl_path}"
        end

        content = File.read(rxl_path)
        bib = Relaton::Bib::Item.from_xml(content)
        build_from_bib(bib, rxl_path)
      rescue StandardError => e
        Metanorma::Release.logger.warn "Failed to parse RXL #{rxl_path}: #{e.message}"
        fallback_from_rxl(rxl_path)
      end

      class << self
        private

        def build_from_bib(bib, rxl_path)
          identifier = bib.docidentifier&.first&.content || ""
          slug = SlugStrategy.slug_from_identifier(identifier)
          output_dir = File.dirname(rxl_path)
          base_name = File.basename(rxl_path, ".rxl")

          Publication.new(
            identifier: identifier, slug: slug,
            title: bib.title&.first&.content || "",
            edition: extract_edition(bib),
            stage: extract_stage(bib),
            doctype: extract_doctype(bib),
            revdate: extract_revdate(bib),
            files: discover_files(output_dir, base_name),
            channels: [], source: nil
          )
        end

        def extract_edition(bib)
          ed = bib.edition
          return "1" unless ed

          ed.is_a?(String) ? ed : ed.content.to_s
        end

        def extract_stage(bib)
          stage = bib.status&.stage
          return "" unless stage

          stage.is_a?(String) ? stage : stage.content.to_s
        end

        def extract_doctype(bib)
          doctype = bib.ext&.doctype
          return "" unless doctype

          doctype.is_a?(String) ? doctype : doctype.content.to_s
        end

        def extract_revdate(bib)
          date = bib.date&.find { |d| d.type == "published" } || bib.date&.first
          return nil unless date

          val = date.at
          val&.to_s
        rescue StandardError
          nil
        end

        # Canonical compiled outputs only: build artifacts (error dumps,
        # presentation XML, Asciidoc logs, alternate renders) are not
        # publication assets.
        CANONICAL_FILES = %w[.html .mnd.html .pdf .doc .xml .rxl].freeze

        def discover_files(output_dir, base_name)
          CANONICAL_FILES.filter_map do |suffix|
            path = File.join(output_dir, "#{base_name}#{suffix}")
            next unless File.file?(path)

            name = File.basename(path)
            format = suffix == ".mnd.html" ? "mnd" : suffix.delete_prefix(".")
            PublicationFile.new(format: format, name: name, path: name)
          end
        end

        def fallback_from_rxl(rxl_path)
          base_name = File.basename(rxl_path, ".rxl")
          slug = SlugStrategy.slug_from_identifier(base_name)
          Publication.new(
            identifier: base_name, slug: slug, title: "",
            edition: "0", stage: "", doctype: "",
            revdate: nil, files: [], channels: [], source: nil
          )
        end
      end
    end
  end
end
