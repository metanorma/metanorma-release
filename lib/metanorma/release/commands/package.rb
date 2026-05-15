# frozen_string_literal: true

module Metanorma
  module Release
    class PackageCommand
      Config = Struct.new(
        :output_dir, :dest, :manifest, :config_source,
        keyword_init: true
      )

      include ConfigResolver

      def initialize(config)
        @config = config
      end

      def call
        manifest = load_manifest(@config.manifest)
        channel_config = resolve_channel_config(@config.config_source, manifest)

        deps = ReleasePipeline::Dependencies.new(
          extractor: RxlExtractor.new,
          filters: [],
          change_detector: ContentHashChangeDetector.new(previous_releases: {}),
          packager: ZipPackager.new,
          publisher: PlatformFactory.build_publisher('null', {}),
          naming_registry: NamingRegistry.default_registry,
          manifest: manifest,
          channel_override: nil,
          channel_config: channel_config
        )

        pipeline_config = ReleasePipeline::Config.new(
          output_dir: @config.output_dir,
          manifest_path: @config.manifest,
          force: false,
          force_replace_patterns: nil,
          concurrency: 4,
          default_visibility: 'public'
        )

        ReleasePipeline.new(deps).run(pipeline_config)
      end
    end
  end
end
