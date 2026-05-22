# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    class ReleaseCommand
      Config = Struct.new(
        :output_dir, :platform, :manifest, :force,
        :force_replace, :channels, :concurrency, :token, :config_source,
        keyword_init: true
      )

      def initialize(config)
        @config = config
      end

      def call
        config = load_config
        options = { token: @config.token }
        publisher = PlatformFactory.build_publisher(@config.platform, options)
        channel_override = Channel.parse_list(@config.channels) if @config.channels

        deps = ReleasePipeline::Dependencies.new(
          extractor: Publication,
          filters: [],
          change_detector: ContentHashChangeDetector.new(previous_releases: {}),
          packager: ZipPackager.new(output_dir: @config.output_dir),
          publisher: publisher,
          slug_registry: SlugRegistry.from_config(config),
          manifest: nil,
          channel_override: channel_override,
          config: config,
        )

        pipeline_config = ReleasePipeline::Config.new(
          output_dir: @config.output_dir,
          manifest_path: @config.manifest,
          force: @config.force,
          force_replace_patterns: @config.force_replace && !@config.force_replace.empty? ? @config.force_replace : nil,
          concurrency: @config.concurrency,
          default_visibility: "public",
        )

        ReleasePipeline.new(deps).run(pipeline_config)
      end

      private

      def load_config
        if @config.config_source && File.exist?(@config.config_source)
          Metanorma::Release::Config.from_file(@config.config_source)
        elsif @config.manifest && File.exist?(@config.manifest)
          Metanorma::Release::Config.from_file(@config.manifest)
        else
          Metanorma::Release::Config.defaults
        end
      end
    end
  end
end
