# frozen_string_literal: true

require 'relaton/bib'
require 'json'
require 'yaml'
require 'fileutils'

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

        attr_reader :flavor_registry
      end

      register_flavor('calconnect') do
        require 'relaton/calconnect'
        Relaton::Calconnect::Item
      end
      register_flavor('cc') do
        require 'relaton/calconnect'
        Relaton::Calconnect::Item
      end
      register_flavor('iso') do
        require 'relaton/iso'
        Relaton::Iso::Item
      end
      register_flavor('iec') do
        require 'relaton/iec'
        Relaton::Iec::BibliographicItem
      end
      register_flavor('ogc') do
        require 'relaton/ogc'
        Relaton::Ogc::BibliographicItem
      end
      register_flavor('ietf') do
        require 'relaton/ietf'
        Relaton::Ietf::BibliographicItem
      end
      register_flavor('bipm') do
        require 'relaton/bipm'
        Relaton::Bipm::BibliographicItem
      end
      register_flavor('itu') do
        require 'relaton/itu'
        Relaton::Itu::BibliographicItem
      end
      register_flavor('nist') do
        require 'relaton/nist'
        Relaton::Nist::BibliographicItem
      end
      register_flavor('un') do
        require 'relaton/un'
        Relaton::Un::BibliographicItem
      end
      register_flavor('bsi') do
        require 'relaton/bsi'
        Relaton::Bsi::BibliographicItem
      end
      register_flavor('ribose') do
        require 'relaton/ribose'
        Relaton::Ribose::Item
      end

      def initialize(flavor: nil, registry_name: 'Document Registry')
        @flavor = flavor
        @registry_name = registry_name
      end

      def enrich(document_index, output_dir, bib_dir: 'relaton')
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
        warn '  (relaton gem not available — bibliography skipped)'
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
          rxl = doc.files.find { |f| f.extension == 'rxl' }
          path = rxl && File.join(output_dir, rxl.path)

          bib = (klass.from_xml(File.read(path)) if path && File.exist?(path))

          enriched = doc.to_h
          enriched['bibliographic'] = bib.to_h if bib
          enriched
        rescue StandardError => e
          warn "  Skip #{File.basename(path)}: #{e.message}"
          doc.to_h
        end
      end

      def write_index(documents, dest)
        FileUtils.mkdir_p(dest)
        index = { 'root' => { 'title' => @registry_name, 'items' => documents } }
        File.write(File.join(dest, 'index.json'), JSON.pretty_generate(index))
        File.write(File.join(dest, 'index.yaml'), YAML.dump(index))
      end
    end
  end
end
