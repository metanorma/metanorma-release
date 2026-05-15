# frozen_string_literal: true

require 'json'
require 'fileutils'

module Metanorma
  module Release
    module Platform
      module Local
        class Publisher
          include Metanorma::Release::Publisher

          def initialize(output_dir:)
            @output_dir = output_dir
          end

          def publish(tag, artifact, metadata, channels:, force_replace: false)
            FileUtils.mkdir_p(@output_dir)

            zip_dest = File.join(@output_dir, artifact.asset_name)
            meta_dest = File.join(@output_dir, meta_file_name(artifact.asset_name))

            if force_replace
              File.delete(zip_dest) if File.exist?(zip_dest)
              File.delete(meta_dest) if File.exist?(meta_dest)
            end

            FileUtils.cp(artifact.zip_path, zip_dest)
            File.write(meta_dest, metadata.to_json)

            PublishResult.new(tag: tag.to_s, url: "file://#{File.expand_path(zip_dest)}", created?: true)
          end

          private

          def meta_file_name(asset_name)
            base = asset_name.sub(/\.zip$/, '')
            "#{base}.meta.json"
          end
        end
      end
    end
  end
end
