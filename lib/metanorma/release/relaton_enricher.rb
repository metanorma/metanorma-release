# frozen_string_literal: true

require "relaton/bib"
require "json"
require "yaml"
require "fileutils"

module Metanorma
  module Release
    class RelatonEnricher
      EnrichResult = Struct.new(:item_count, :output_dir, keyword_init: true)

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
        items = parse_rxl_files(document_index, output_dir, klass)
        return nil if items.empty?

        dest = File.join(output_dir, bib_dir)
        write_index(items, dest)

        EnrichResult.new(item_count: items.length, output_dir: dest)
      end

      private

      def resolve_flavor(document_index)
        @flavor || document_index.documents.first&.flavor
      end

      def resolve_class(flavor)
        loader = self.class.flavor_registry[flavor.to_s]
        if loader
          loader.call
        else
          Relaton::Bib::Item
        end
      rescue LoadError
        warn "  (relaton-#{flavor} gem not available — using base Relaton::Bib::Item)"
        Relaton::Bib::Item
      end

      def parse_rxl_files(document_index, output_dir, klass)
        document_index.documents.filter_map do |doc|
          rxl = doc.files.find { |f| f.extension == "rxl" }
          next unless rxl

          path = File.join(output_dir, rxl.path)
          next unless File.exist?(path)

          klass.from_xml(File.read(path)).to_h
        rescue StandardError => e
          warn "  Skip #{File.basename(path)}: #{e.message}"
          nil
        end
      end

      def write_index(items, dest)
        FileUtils.mkdir_p(dest)
        index = { "root" => { "title" => @registry_name, "items" => items } }
        File.write(File.join(dest, "index.json"), JSON.pretty_generate(index))
        File.write(File.join(dest, "index.yaml"), YAML.dump(index))
      end
    end
  end
end
