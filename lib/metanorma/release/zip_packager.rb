# frozen_string_literal: true

begin
  require 'zip'
rescue LoadError
  raise LoadError, "The rubyzip gem is required for ZipPackager. Add `gem 'rubyzip'` to your Gemfile."
end

module Metanorma
  module Release
    class ZipPackager
      include Packager

      def package(metadata, canonical_base:)
        dir = metadata.output_dir
        base = metadata.file_base_name
        files = Dir.glob(File.join(dir, "#{base}.*")).reject { |f| File.directory?(f) }

        zip_path = File.join(dir, "#{canonical_base}.zip")
        File.delete(zip_path) if File.exist?(zip_path)
        Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
          files.each do |file|
            ext = File.extname(file)
            entry_name = "#{canonical_base}#{ext}"
            zipfile.add(entry_name, file)
          end
        end

        Artifact.new(
          zip_path: zip_path,
          asset_name: "#{canonical_base}.zip",
          size: File.size(zip_path)
        )
      end
    end
  end
end
