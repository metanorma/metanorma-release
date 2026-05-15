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
          channels: (@config.channels || []).map { |s| Channel.parse(s) }
        )
        stage_filter = StageFilter.new(stages: @config.stages || [])
        routing = FileRoutingFactory.from_name(@config.file_routing)
        asset_processor = AssetProcessor.new(
          output_dir: @config.output_dir,
          routing: routing,
          canonicalize: true
        )
        delta_state = if @config.cache_dir
                        DeltaState.new(
                          cache_store: FileCacheStore.new(@config.cache_dir),
                          output_dir: @config.output_dir
                        )
                      else
                        NullDeltaState.new
                      end

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

        stamp_primary_identifiers!(enrich_result.documents)
      rescue LoadError
        warn '  (relaton gem not available — bibliography skipped)'
      end

      def stamp_primary_identifiers!(documents)
        documents.each do |doc|
          bib = doc['bibliographic']
          next unless bib

          ids = bib['docidentifier']
          next unless ids&.any?

          primary = ids.find { |di| di['primary'] == true } || ids.first
          doc['primary_identifier'] = primary['content']
        end
      end

      def zip_output
        require 'rubygems/package'
        require 'zlib'

        dir = @config.output_dir
        zip_path = "#{dir}.zip"

        Dir.chdir(File.dirname(dir)) do
          IO.write(zip_path, '')
          Zlib::GzipWriter.open(zip_path) do |gz|
            Gem::Package::TarWriter.new(gz) do |tar|
              Dir.glob("#{File.basename(dir)}/**/*").each do |file|
                next if File.directory?(file)

                tar.add_file(file, 0o644) do |io|
                  io.write(File.read(file))
                end
              end
            end
          end
        end
      end
    end
  end
end
