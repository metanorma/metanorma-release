# frozen_string_literal: true

module Metanorma
  module Release
    class PublishCommand
      Config = Struct.new(
        :output_dir, :platform, :manifest, :force,
        :force_replace, :channels, :concurrency, :token, :config_source,
        keyword_init: true
      )

      include ConfigResolver

      def initialize(config)
        @config = config
      end

      def call
        manifest = load_manifest(@config.manifest)
        channel_config = resolve_channel_config(@config.config_source, manifest)

        options = { token: @config.token }
        publisher = PlatformFactory.build_publisher(@config.platform, options)
        channel_override = Channel.parse_list(@config.channels) if @config.channels

        deps = ReleasePipeline::Dependencies.new(
          extractor: RxlExtractor.new,
          filters: [],
          change_detector: ContentHashChangeDetector.new(previous_releases: {}),
          packager: ZipPackager.new,
          publisher: publisher,
          naming_registry: NamingRegistry.default_registry,
          manifest: manifest,
          channel_override: channel_override,
          channel_config: channel_config
        )

        pipeline_config = ReleasePipeline::Config.new(
          output_dir: @config.output_dir,
          manifest_path: @config.manifest,
          force: @config.force,
          force_replace_patterns: @config.force_replace && !@config.force_replace.empty? ? @config.force_replace : nil,
          concurrency: @config.concurrency,
          default_visibility: 'public'
        )

        ReleasePipeline.new(deps).run(pipeline_config)
      end
    end
  end
end
