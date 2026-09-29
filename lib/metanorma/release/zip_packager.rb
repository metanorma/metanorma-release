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

      def initialize(output_dir: nil)
        @output_dir = output_dir
      end

      def package(publication, canonical_base:)
        dir = @output_dir || derive_dir(publication)
        slug = publication.slug

        files = Dir.glob(File.join(dir, "**", "#{slug}.*")).reject do |f|
          File.directory?(f)
        end
        if files.empty?
          identifier = File.basename(publication.identifier.to_s)
          files = Dir.glob(File.join(dir, "**",
                                     "#{identifier}.*")).reject do |f|
            File.directory?(f)
          end
        end

        zip_path = File.join(dir, "#{canonical_base}.zip")
        FileUtils.mkdir_p(File.dirname(zip_path))
        FileUtils.rm_f(zip_path)
        Zip::File.open(zip_path, create: true) do |zipfile|
          files.each do |file|
            # Preserve the full suffix (document.mnd.html keeps .mnd.html)
            # so parallel renders do not collide on the base extension.
            suffix = File.basename(file).sub(File.basename(file, ".*"), "")
            entry_name = "#{canonical_base}#{suffix}"
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

      def derive_dir(publication)
        publication.base_dir
      end
    end
  end
end
