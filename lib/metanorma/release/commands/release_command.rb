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
        org_config = load_org_config
        config = load_config(org_config: org_config)
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

      def load_config(org_config: nil)
        if @config.config_source && File.exist?(@config.config_source)
          Metanorma::Release::Config.from_file(@config.config_source, org_config: org_config)
        elsif @config.manifest && File.exist?(@config.manifest)
          Metanorma::Release::Config.from_file(@config.manifest, org_config: org_config)
        else
          Metanorma::Release::Config.defaults(org_config: org_config)
        end
      end

      def load_org_config
        path = find_config_path
        return nil unless path

        org_ref = extract_org_ref(path)
        return nil unless org_ref

        resolve_org_config(org_ref)
      end

      def find_config_path
        if @config.config_source && File.exist?(@config.config_source)
          @config.config_source
        elsif @config.manifest && File.exist?(@config.manifest)
          @config.manifest
        end
      end

      def extract_org_ref(path)
        raw = YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
        raw["org"]
      end

      def resolve_org_config(org_ref)
        ref = OrgConfig.parse_ref(org_ref)
        local_path = OrgConfig.remote_path(ref)
        return OrgConfig.from_file(local_path) if File.exist?(local_path)

        fetch_org_config_from_github(ref)
      end

      def fetch_org_config_from_github(ref)
        require "octokit"
        token = @config.token || ENV.fetch("GITHUB_TOKEN", nil)
        client = token ? Octokit::Client.new(access_token: token) : Octokit::Client.new
        remote = OrgConfig.remote_path(ref)
        contents = client.contents("#{ref.owner}/#{ref.repo}", path: remote)
        decoded = Base64.decode64(contents[:content])
        OrgConfig.from_yaml(decoded)
      rescue StandardError => e
        warn "  (org config not loaded from #{ref.owner}/#{ref.repo}: #{e.message})"
        OrgConfig.defaults
      end
    end
  end
end
