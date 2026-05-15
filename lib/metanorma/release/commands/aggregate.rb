# frozen_string_literal: true

module Metanorma
  module Release
    class AggregateCommand
      Config = Struct.new(
        :source, :organizations, :topic, :repos, :repo_pattern, :local_path,
        :channels, :stages, :output_dir, :file_routing, :cache_dir,
        :include_drafts, :concurrency, :min_documents, :token, :zip,
        keyword_init: true
      )

      def initialize(config)
        @config = config
      end

      def call
        result = run_aggregation
        enrich(result) if result.documents.any?
        zip_output if @config.zip
        result
      end

      private

      def run_aggregation
        adapters = PlatformFactory.build_aggregation_adapters(
          source: @config.local_path ? "local:#{@config.local_path}" : @config.source,
          organizations: @config.organizations,
          topic: @config.topic,
          repos: @config.repos,
          token: @config.token
        )

        channel_filter = ChannelFilter.new(
          channels: Channel.parse_list(@config.channels)
        )
        stage_filter = StageFilter.new(@config.stages || [])
        routing = FileRoutingFactory.from_name(@config.file_routing)
        asset_processor = AssetProcessor.new(
          output_dir: @config.output_dir,
          routing: routing,
          canonicalize: true
        )
        delta_state = build_delta_state

        deps = AggregationPipeline::Dependencies.new(
          discoverer: adapters[:discoverer],
          fetcher: adapters[:fetcher],
          manifest_reader: adapters[:manifest_reader],
          channel_filter: channel_filter,
          stage_filter: stage_filter,
          asset_processor: asset_processor,
          delta_state: delta_state
        )

        config = AggregationPipeline::Config.new(
          organizations: @config.organizations,
          channels: @config.channels,
          topic: @config.topic,
          concurrency: @config.concurrency,
          include_drafts: @config.include_drafts,
          fail_on_error: false
        )

        AggregationPipeline.new(deps).run(config, @config.output_dir)
      end

      def build_delta_state
        return NullDeltaState.new unless @config.cache_dir

        DeltaState.new(
          cache_store: FileCacheStore.new(@config.cache_dir),
          output_dir: @config.output_dir
        )
      end

      def enrich(result)
        index = DocumentIndex.from_documents(
          result.documents,
          parameters: IndexParameters.new(
            organizations: @config.organizations,
            channels: @config.channels || [],
            topic: @config.topic,
            repo_count: result.repo_count
          )
        )
        enricher = RelatonEnricher.new
        enrich_result = enricher.enrich(index, @config.output_dir)
        return unless enrich_result

        stamp_primary_identifiers(enrich_result.documents)
      rescue LoadError
        warn '  (relaton gem not available — bibliography skipped)'
      end

      def stamp_primary_identifiers(documents)
        documents.map do |doc|
          next doc unless doc['bibliographic']

          ids = doc['bibliographic']['docidentifier']
          next doc unless ids&.any?

          primary = ids.find { |di| di['primary'] == true } || ids.first
          doc.merge('primary_identifier' => primary['content'])
        end
      end

      def zip_output
        require 'zip'

        dir = @config.output_dir
        zip_path = "#{dir}.zip"

        Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
          Dir.glob("#{dir}/**/*").each do |file|
            next if File.directory?(file)

            entry_name = file.sub("#{File.dirname(dir)}/", '')
            zipfile.add(entry_name, file)
          end
        end
      end
    end
  end
end
