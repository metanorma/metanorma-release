# frozen_string_literal: true

require "relaton/bib"
require "json"
require "yaml"
require "fileutils"

module Metanorma
  module Release
    class RelatonEnricher
      EnrichResult = Struct.new(
        :item_count, :output_dir, :documents,
        keyword_init: true
      )

      @flavor_registry = {}

      class << self
        def register_flavor(name, &loader)
          @flavor_registry[name.to_s] = loader
        end

        def flavor_registry
          @flavor_registry
        end
      end

      register_flavor("calconnect") { require "relaton/calconnect"; Relaton::Calconnect::Item }
      register_flavor("cc")         { require "relaton/calconnect"; Relaton::Calconnect::Item }
      register_flavor("iso")        { require "relaton/iso"; Relaton::Iso::Item }
      register_flavor("iec")        { require "relaton/iec"; Relaton::Iec::BibliographicItem }
      register_flavor("ogc")        { require "relaton/ogc"; Relaton::Ogc::BibliographicItem }
      register_flavor("ietf")       { require "relaton/ietf"; Relaton::Ietf::BibliographicItem }
      register_flavor("bipm")       { require "relaton/bipm"; Relaton::Bipm::BibliographicItem }
      register_flavor("itu")        { require "relaton/itu"; Relaton::Itu::BibliographicItem }
      register_flavor("nist")       { require "relaton/nist"; Relaton::Nist::BibliographicItem }
      register_flavor("un")         { require "relaton/un"; Relaton::Un::BibliographicItem }
      register_flavor("bsi")        { require "relaton/bsi"; Relaton::Bsi::BibliographicItem }
      register_flavor("ribose")     { require "relaton/ribose"; Relaton::Ribose::Item }

      def initialize(flavor: nil, registry_name: "Document Registry")
        @flavor = flavor
        @registry_name = registry_name
      end

      def enrich(document_index, output_dir, bib_dir: "relaton")
        return nil if document_index.empty?

        flavor = resolve_flavor(document_index)
        klass = resolve_class(flavor)
        documents = enrich_documents(document_index, output_dir, klass)
        return nil if documents.empty?

        dest = File.join(output_dir, bib_dir)
        write_index(documents, dest)

        EnrichResult.new(item_count: documents.length, output_dir: dest,
                         documents: documents)
      rescue LoadError
        warn "  (relaton gem not available — bibliography skipped)"
        nil
      end

      private

      def resolve_flavor(document_index)
        @flavor || document_index.documents.first&.flavor
      end

      def resolve_class(flavor)
        loader = self.class.flavor_registry[flavor.to_s]
        return loader.call if loader

        Relaton::Bib::Item
      rescue LoadError
        warn "  (relaton-#{flavor} gem not available — using base Relaton::Bib::Item)"
        Relaton::Bib::Item
      end

      def enrich_documents(document_index, output_dir, klass)
        document_index.documents.map do |doc|
          rxl = doc.files.find { |f| f.extension == "rxl" }
          path = rxl && File.join(output_dir, rxl.path)

          bib = if path && File.exist?(path)
                  klass.from_xml(File.read(path))
                end

          enriched = doc.to_h
          enriched["bibliographic"] = bib.to_h if bib
          enriched
        rescue StandardError => e
          warn "  Skip #{File.basename(path)}: #{e.message}"
          doc.to_h
        end
      end

      def write_index(documents, dest)
        FileUtils.mkdir_p(dest)
        index = { "root" => { "title" => @registry_name, "items" => documents } }
        File.write(File.join(dest, "index.json"), JSON.pretty_generate(index))
        File.write(File.join(dest, "index.yaml"), YAML.dump(index))
      end
    end
  end
end
