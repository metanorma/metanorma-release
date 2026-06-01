# frozen_string_literal: true

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
          packager: ZipPackager.new(output_dir: @config.output_dir),
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

        ReleasePipeline.new(deps).run(pipeline_config)
      end
    end
  end
end
