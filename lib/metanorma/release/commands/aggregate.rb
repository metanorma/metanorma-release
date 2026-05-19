# frozen_string_literal: true

require "base64"
require "yaml"

module Metanorma
  module Release
    class AggregateCommand
      Config = Struct.new(
        :source, :organizations, :topic, :repos, :repo_pattern, :local_path,
        :channels, :stages, :output_dir, :file_routing, :cache_dir,
        :data_dir, :include_drafts, :concurrency, :min_documents, :token,
        :create_zip, :org,
        keyword_init: true
      )

      DEFAULT_CONFIG_FILE = "metanorma.aggregate.yml"
      DEFAULT_CACHE_DIR = ".cache/aggregate"

      def initialize(config)
        @config = config
        @org_config = nil
      end

      def call
        load_org_config
        result = run_aggregation
        return result unless result.publications.any?

        index = build_index(result)
        site = Site.new(index: index, output_dir: @config.output_dir,
                        data_dir: @config.data_dir, org_config: @org_config)
        site.write!
        site.enrich!
        site.package! if @config.create_zip

        stamp_primary_identifiers(index)
        result
      end

      def self.build_config(cli_options)
        file_data = load_config_file(cli_options[:config])
        merged = merge_config(file_data, cli_options)
        Config.new(
          source: merged[:source],
          organizations: merged[:organizations],
          topic: merged[:topic],
          repos: merged[:repos],
          channels: merged[:channels],
          stages: merged[:stages],
          output_dir: merged[:output_dir],
          file_routing: merged[:file_routing],
          cache_dir: merged[:cache_dir] || DEFAULT_CACHE_DIR,
          data_dir: merged[:data_dir],
          include_drafts: merged[:include_drafts],
          concurrency: merged[:concurrency],
          min_documents: merged[:min_documents],
          token: merged[:token],
          create_zip: merged[:create_zip],
          org: merged[:org],
        )
      end

      def self.load_config_file(path)
        path ||= DEFAULT_CONFIG_FILE
        return {} unless File.exist?(path)

        YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
      end

      def self.merge_config(file_data, cli_options)
        gh = file_data["github"] || {}
        {
          source: cli_options[:source] || file_data["source"],
          organizations: cli_options[:organizations].any? ? cli_options[:organizations] : Array(gh["organizations"]),
          topic: cli_options[:topic] || gh["topic"],
          repos: cli_options[:repos] || file_data["repos"],
          channels: cli_options[:channels].any? ? cli_options[:channels] : Array(file_data["channels"]),
          stages: cli_options[:stages].any? ? cli_options[:stages] : Array(file_data["stages"]),
          output_dir: cli_options[:output_dir] || file_data["output_dir"],
          file_routing: cli_options[:file_routing] || file_data["file_routing"] || "by-document",
          cache_dir: cli_options[:cache_dir] || file_data["cache_dir"],
          data_dir: cli_options[:data_dir] || file_data["data_dir"],
          include_drafts: cli_options[:include_drafts] || file_data["include_drafts"],
          concurrency: cli_options[:concurrency] || file_data["concurrency"],
          min_documents: cli_options[:min_documents] || file_data["min_documents"],
          token: cli_options[:token],
          create_zip: cli_options[:create_zip],
          org: file_data["org"],
        }
      end

      private

      def run_aggregation
        adapters = PlatformFactory.build_aggregation_adapters(
          source: @config.local_path ? "local:#{@config.local_path}" : @config.source,
          organizations: @config.organizations,
          topic: @config.topic,
          repos: @config.repos,
          token: @config.token,
        )

        metadata_filter = MetadataFilter.new(
          channels: Channel.parse_list(@config.channels),
          stages: @config.stages || [],
        )
        routing = FileRoutingFactory.from_name(@config.file_routing)
        asset_processor = AssetProcessor.new(
          output_dir: @config.output_dir,
          routing: routing,
          canonicalize: true,
        )
        delta_state = build_delta_state

        deps = AggregationPipeline::Dependencies.new(
          discoverer: adapters[:discoverer],
          fetcher: adapters[:fetcher],
          manifest_reader: adapters[:manifest_reader],
          metadata_filter: metadata_filter,
          asset_processor: asset_processor,
          delta_state: delta_state,
        )

        config = AggregationPipeline::Config.new(
          organizations: @config.organizations,
          channels: @config.channels,
          topic: @config.topic,
          concurrency: @config.concurrency,
          include_drafts: @config.include_drafts,
          fail_on_error: false,
        )

        AggregationPipeline.new(deps).run(config, @config.output_dir)
      end

      def build_index(result)
        Index.from_documents(
          result.publications,
          parameters: {
            organizations: @config.organizations,
            channels: @config.channels || [],
            topic: @config.topic,
            repo_count: result.repo_count,
          },
        )
      end

      def build_delta_state
        return NullDeltaState.new unless @config.cache_dir

        DeltaState.new(
          cache_store: FileCacheStore.new(@config.cache_dir),
          output_dir: @config.output_dir,
        )
      end

      def stamp_primary_identifiers(index)
        index.publications.each do |pub|
          next unless pub.to_h["bibliographic"]

          ids = pub.to_h.dig("bibliographic", "docidentifier")
          next unless ids&.any?

          primary = ids.find { |di| di["primary"] == true } || ids.first
          pub.to_h.merge("primary_identifier" => primary["content"])
        end
      rescue LoadError
        warn "  (relaton gem not available — bibliography skipped)"
      end

      def load_org_config
        return unless @config.org

        ref = OrgConfig.parse_ref(@config.org)
        local_path = OrgConfig.remote_path(ref)
        @org_config = File.exist?(local_path) ? OrgConfig.from_file(local_path) : fetch_org_config_from_github(ref)
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
