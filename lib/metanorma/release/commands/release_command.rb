# frozen_string_literal: true

module Metanorma
  module Release
    class ReleaseCommand
      extend ConfigLoader

      Config = Struct.new(
        :output_dir, :platform, :manifest, :force,
        :force_replace, :channels, :concurrency, :token, :config_source,
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
        options = { token: @config.token }
        publisher = PlatformFactory.build_publisher(@config.platform, options)
        channel_override = Channel.parse_list(@config.channels) if @config.channels

        previous_releases = build_previous_releases
        deps = ReleasePipeline::Dependencies.new(
          extractor: RxlExtractor,
          filters: [],
          change_detector: ContentHashChangeDetector.new(previous_releases: previous_releases,
                                                         output_dir: @config.output_dir),
          packager: ZipPackager.new(output_dir: @config.output_dir),
          publisher: publisher,
          slug_registry: SlugRegistry.from_config(config),
          manifest: nil,
          channel_override: channel_override,
          config: config,
        )

        pipeline_config = ReleasePipeline::Config.new(
          output_dir: @config.output_dir,
          force: @config.force,
          force_replace_patterns: @config.force_replace && !@config.force_replace.empty? ? @config.force_replace : nil,
          concurrency: @config.concurrency,
        )

        ReleasePipeline.new(deps).run(pipeline_config)
      end

      private

      def build_previous_releases
        pubs = RxlExtractor.discover(@config.output_dir)
        pubs.each_with_object({}) do |pub, map|
          pub.slug
          registry = SlugRegistry.default
          strategy = registry.resolve(SlugStrategy.publisher_from_identifier(pub.identifier))
          tag_info = strategy.compute_tag(pub)
          content_hash = pub.content_hash(from_directory: @config.output_dir)
          map[tag_info[:tag]] = content_hash if content_hash
        end
      end
    end
  end
end
