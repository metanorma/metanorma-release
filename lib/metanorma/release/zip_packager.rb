# frozen_string_literal: true

begin
  require "zip"
rescue LoadError
  raise LoadError,
        "The rubyzip gem is required for ZipPackager. Add `gem 'rubyzip'` to your Gemfile."
end

module Metanorma
  module Release
    Artifact = Struct.new(:zip_path, :asset_name, :size, keyword_init: true)

    class ZipPackager
      include Packager

      # Raised when no source files resolve for a publication — packaging
      # must never emit an empty archive silently.
      class EmptyPackageError < StandardError; end

      def initialize(output_dir: nil)
        @output_dir = output_dir
      end

      def package(publication, canonical_base:)
        dir = @output_dir || derive_dir(publication)
        slug = publication.slug

        files = resolve_files(publication, dir)
        if files.empty?
          raise EmptyPackageError,
                "no files resolved for #{slug} in #{dir} (files: " \
                "#{publication.files.map(&:path).join(', ')}"
        end

        zip_path = File.join(dir, "#{canonical_base}.zip")
        FileUtils.rm_f(zip_path)
        Zip::File.open(zip_path, create: true) do |zipfile|
          seen = []
          files.each do |file|
            ext = File.extname(file)
            entry_name = "#{canonical_base}#{ext}"
            if seen.include?(entry_name)
              Metanorma::Release.logger.warn(
                "skipping duplicate zip entry #{entry_name} (#{file})",
              )
              next
            end
            seen << entry_name
            zipfile.add(entry_name, file)
          end
        end

        Artifact.new(
          zip_path: zip_path,
          asset_name: "#{canonical_base}.zip",
          size: File.size(zip_path),
        )
      end

      private

      # Publications extracted from a site layout carry their source
      # directory (base_dir) and a file list; slug globbing is the
      # fallback for publications whose files were not discoverable that
      # way (e.g. GitHub release assets).
      def resolve_files(publication, dir)
        base = publication.base_dir.to_s
        if publication.files.any? && base != "." && File.directory?(base)
          publication.files.filter_map do |f|
            path = File.join(base, f.path)
            path unless File.directory?(path)
          end.select { |p| File.file?(p) }
        else
          files = Dir.glob(File.join(dir, "**", "#{publication.slug}.*"))
          files = Dir.glob(File.join(dir, "**",
                                     "#{File.basename(publication.identifier.to_s)}.*")) if files.empty?
          files.reject { |f| File.directory?(f) }
        end
      end

      def derive_dir(publication)
        publication.base_dir
      end
    end
  end
end
