# frozen_string_literal: true

require "json"
require "yaml"
require "fileutils"

module Metanorma
  module Release
    class Site
      attr_reader :index, :output_dir

      def initialize(index:, output_dir:)
        @index = index
        @output_dir = output_dir
      end

      def write!
        FileUtils.mkdir_p(output_dir)
        index.write(File.join(output_dir, "index.json"))
      end

      def enrich!
        return if index.empty?

        documents = index.publications.map do |pub|
          rxl_file = pub.files.find { |f| f.format == "rxl" }
          next pub.to_h unless rxl_file

          rxl_path = File.join(output_dir, rxl_file.path)
          next pub.to_h unless File.exist?(rxl_path)

          bib = Relaton::Bib::Item.from_xml(File.read(rxl_path))
          enriched = pub.to_h
          enriched["bibliographic"] = bib.to_h
          enriched
        rescue StandardError => e
          warn "  Skip #{pub.identifier}: #{e.message}"
          pub.to_h
        end

        dest = File.join(output_dir, "relaton")
        FileUtils.mkdir_p(dest)
        index_data = { "root" => { "title" => "Document Registry",
                                   "items" => documents.compact } }
        File.write(File.join(dest, "index.json"),
                   JSON.pretty_generate(index_data))
        File.write(File.join(dest, "index.yaml"), YAML.dump(index_data))
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
    end
  end
end
