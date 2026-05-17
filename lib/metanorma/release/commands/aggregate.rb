# frozen_string_literal: true

module Metanorma
  module Release
    class AggregateCommand
      Config = Struct.new(
        :source, :organizations, :topic, :repos, :repo_pattern, :local_path,
        :channels, :stages, :output_dir, :file_routing, :cache_dir,
        :include_drafts, :concurrency, :min_documents, :token, :create_zip,
        keyword_init: true
      )

      def initialize(config)
        @config = config
      end

      def call
        result = run_aggregation
        return result unless result.publications.any?

        index = build_index(result)
        site = Site.new(index: index, output_dir: @config.output_dir)
        site.write!
        site.enrich!
        site.package! if @config.create_zip

        stamp_primary_identifiers(index)
        result
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
    end
  end
end
