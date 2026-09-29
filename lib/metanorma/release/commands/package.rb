# frozen_string_literal: true

require "json"

module Metanorma
  module Release
    class PackageCommand
      extend ConfigLoader

      Config = Struct.new(
        :output_dir, :dest, :manifest, :config_source,
        keyword_init: true
      )

      def initialize(config)
        @config = config
      end

      def call
        config = self.class.load_config(
          config_source: @config.config_source,
          manifest: @config.manifest,
        )
        deps = ReleasePipeline::Dependencies.new(
          extractor: RxlExtractor,
          filters: [],
          change_detector: ContentHashChangeDetector.new(previous_releases: {},
                                                         output_dir: @config.output_dir),
          packager: ZipPackager.new(output_dir: @config.dest),
          publisher: PlatformFactory.build_publisher("null", {}),
          slug_registry: SlugRegistry.from_config(config),
          manifest: nil,
          channel_override: nil,
          config: config,
        )

        pipeline_config = ReleasePipeline::Config.new(
          output_dir: @config.output_dir,
          force: false,
          force_replace_patterns: nil,
          concurrency: 4,
        )

        result = ReleasePipeline.new(deps).run(pipeline_config)
        write_metadata_sidecars(result)
        result
      end

      # The aggregate command's local source consumes
      # <canonical>.meta.json + <canonical>.zip pairs; write the sidecar
      # metadata next to each packaged zip.
      def write_metadata_sidecars(result)
        result.released.each_with_index do |pub, i|
          artifact = result.released_artifacts[i]
          next unless artifact

          sidecar = File.join(File.dirname(artifact.zip_path),
                              "#{File.basename(artifact.zip_path, '.zip')}.meta.json")
          File.write(sidecar, JSON.pretty_generate(
            "identifier" => pub.identifier,
            "title" => pub.title,
            "edition" => pub.edition,
            "stage" => pub.stage,
            "doctype" => pub.doctype,
            "revdate" => pub.revdate,
            "channels" => artifact.channels.empty? ? ["public"] : artifact.channels,
            "formats" => pub.files.map(&:format),
          ))
        end
      end
    end
  end
end
