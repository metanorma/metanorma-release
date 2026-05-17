# frozen_string_literal: true

begin
  require "zip"
rescue LoadError
  raise LoadError,
        "The rubyzip gem is required for AssetProcessor. Add `gem 'rubyzip'` to your Gemfile."
end

module Metanorma
  module Release
    class AssetProcessor
      ProcessResult = Struct.new(:files, :channels, keyword_init: true)

      CANONICALIZE_PATTERN = /-ed\d+(\.\d+)?-/

      def initialize(output_dir:, routing:, canonicalize: true)
        @output_dir = output_dir
        @routing = routing
        @canonicalize = canonicalize
      end

      def process(zip_data, metadata)
        files = []

        Dir.mktmpdir do |tmp_dir|
          zip_path = File.join(tmp_dir, "archive.zip")
          File.binwrite(zip_path, zip_data)

          Zip::File.open(zip_path) do |zip_file|
            zip_file.each do |entry|
              next if entry.directory?

              raw_name = File.basename(entry.name)
              file_name = @canonicalize ? canonicalize_name(raw_name) : raw_name
              relative_path = @routing.compute_path(file_name, metadata)
              dest_path = File.join(@output_dir, relative_path)

              FileUtils.mkdir_p(File.dirname(dest_path))
              entry.extract(dest_path) { true }

              ext = File.extname(file_name).delete_prefix(".")
              files << PublicationFile.new(format: ext, name: file_name,
                                           path: relative_path)
            end
          end
        end

        ProcessResult.new(files: files, channels: metadata["channels"])
      end

      private

      def canonicalize_name(name)
        name.sub(/-ed\d+(\.\d+)?-(?=[a-z0-9])/, "-")
          .sub(/-ed\d+(\.\d+)?\./, ".")
      end
    end
  end
end
