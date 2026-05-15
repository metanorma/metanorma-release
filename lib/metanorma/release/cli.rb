# frozen_string_literal: true

require 'optparse'

module Metanorma
  module Release
    module CLI
      module_function

      def run(argv)
        command = argv.shift
        case command
        when 'package'   then run_package(argv)
        when 'publish'   then run_publish(argv)
        when 'aggregate' then run_aggregate(argv)
        when nil
          warn 'Usage: mn-release <package|publish|aggregate> [options]'
          exit 2
        else
          warn "Unknown command: #{command}"
          exit 2
        end
      end

      def run_package(argv)
        options = { output_dir: '_site', dest: 'dist', manifest: 'metanorma.release.yml', config: nil }
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: mn-release package [options]'
          opts.on('--output-dir DIR', 'Compiled docs directory') { |v| options[:output_dir] = v }
          opts.on('--dest DIR', 'Destination for packages') { |v| options[:dest] = v }
          opts.on('--manifest FILE', 'Release manifest file') { |v| options[:manifest] = v }
          opts.on('--config SOURCE', 'Channel config (file path or platform ref)') { |v| options[:config] = v }
        end
        parser.parse!(argv)

        manifest = load_manifest(options[:manifest])
        channel_config = resolve_channel_config(options[:config], manifest)
        extractor = RxlExtractor.new
        change_detector = ContentHashChangeDetector.new(previous_releases: {})
        packager = ZipPackager.new
        publisher = PlatformFactory.build_publisher('null', options)
        naming = NamingRegistry.default_registry

        deps = ReleasePipeline::Dependencies.new(
          extractor: extractor, filters: [], change_detector: change_detector,
          packager: packager, publisher: publisher, naming_registry: naming,
          manifest: manifest, channel_override: nil, channel_config: channel_config
        )
        config = ReleasePipeline::Config.new(
          output_dir: options[:output_dir], manifest_path: options[:manifest],
          force: false, force_replace_patterns: nil, concurrency: 4, default_visibility: 'public'
        )

        pipeline = ReleasePipeline.new(deps)
        result = pipeline.run(config)

        print_package_result(result, options[:dest])
        exit(result.failed.empty? ? 0 : 1)
      end

      def run_publish(argv)
        options = { output_dir: '_site', platform: 'github', manifest: 'metanorma.release.yml',
                    force: false, force_replace: [], channels: nil, concurrency: 4, token: nil,
                    config: nil }
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: mn-release publish [options]'
          opts.on('--platform NAME', 'github|gitlab|local') { |v| options[:platform] = v }
          opts.on('--output-dir DIR', 'Compiled docs directory') { |v| options[:output_dir] = v }
          opts.on('--manifest FILE', 'Release manifest file') { |v| options[:manifest] = v }
          opts.on('--force', 'Force release even if unchanged') { |v| options[:force] = v }
          opts.on('--force-replace PAT', 'Glob patterns for force-replace') { |v| options[:force_replace] << v }
          opts.on('--channels CHANS', 'Override channels (comma-separated)') { |v| options[:channels] = v.split(',') }
          opts.on('--concurrency N', Integer) { |v| options[:concurrency] = v }
          opts.on('--token TOKEN', 'Platform auth token') { |v| options[:token] = v }
          opts.on('--config SOURCE', 'Channel config (file path or platform ref)') { |v| options[:config] = v }
        end
        parser.parse!(argv)

        manifest = load_manifest(options[:manifest])
        channel_config = resolve_channel_config(options[:config], manifest)
        extractor = RxlExtractor.new
        change_detector = ContentHashChangeDetector.new(previous_releases: {})
        packager = ZipPackager.new
        publisher = PlatformFactory.build_publisher(options[:platform], options.merge(token: nil))
        naming = NamingRegistry.default_registry
        channel_override = parse_channels(options[:channels]) if options[:channels]

        deps = ReleasePipeline::Dependencies.new(
          extractor: extractor, filters: [], change_detector: change_detector,
          packager: packager, publisher: publisher, naming_registry: naming,
          manifest: manifest, channel_override: channel_override, channel_config: channel_config
        )
        config = ReleasePipeline::Config.new(
          output_dir: options[:output_dir], manifest_path: options[:manifest],
          force: options[:force], force_replace_patterns: options[:force_replace].empty? ? nil : options[:force_replace],
          concurrency: options[:concurrency], default_visibility: 'public'
        )

        pipeline = ReleasePipeline.new(deps)
        result = pipeline.run(config)

        print_publish_result(result)
        exit(result.failed.empty? ? 0 : 1)
      end

      def run_aggregate(argv)
        options = { source: 'github', organizations: [], topic: 'metanorma-release',
                    repos: nil, channels: [], stages: [], output_dir: '_site/cc',
                    file_routing: 'by-document', cache_dir: nil,
                    include_drafts: false, concurrency: 4, min_documents: 0, token: nil }
        parser = OptionParser.new do |opts|
          opts.banner = 'Usage: mn-release aggregate [options]'
          opts.on('--source SOURCE', 'github|local:PATH') { |v| options[:source] = v }
          opts.on('--organizations ORGS', 'Comma-separated org list') { |v| options[:organizations] = v.split(',') }
          opts.on('--topic TOPIC', 'Repository topic') { |v| options[:topic] = v }
          opts.on('--repos REPOS', 'Explicit repo list (comma-separated)') { |v| options[:repos] = v.split(',') }
          opts.on('--channels CHANS', 'Filter channels (comma-separated)') { |v| options[:channels] = v.split(',') }
          opts.on('--stages STAGES', 'Filter stages (comma-separated)') { |v| options[:stages] = v.split(',') }
          opts.on('--output-dir DIR', 'Output directory') { |v| options[:output_dir] = v }
          opts.on('--file-routing MODE', 'by-document|flat|by-format') { |v| options[:file_routing] = v }
          opts.on('--cache-dir DIR', 'Cache directory') { |v| options[:cache_dir] = v }
          opts.on('--[no-]include-drafts', 'Include draft releases') { |v| options[:include_drafts] = v }
          opts.on('--concurrency N', Integer) { |v| options[:concurrency] = v }
          opts.on('--min-documents N', Integer) { |v| options[:min_documents] = v }
          opts.on('--token TOKEN', 'Platform auth token') { |v| options[:token] = v }
        end
        parser.parse!(argv)

        adapters = PlatformFactory.build_aggregation_adapters(options)
        channel_filter = ChannelFilter.new(channels: parse_channels(options[:channels]))
        stage_filter = StageFilter.new(stages: options[:stages])
        routing = FileRoutingFactory.from_name(options[:file_routing])
        asset_processor = AssetProcessor.new(output_dir: options[:output_dir], routing: routing, canonicalize: true)
        delta_state = if options[:cache_dir]
                        DeltaState.new(cache_store: FileCacheStore.new(options[:cache_dir]),
                                       output_dir: options[:output_dir])
                      else
                        NullDeltaState.new
                      end

        deps = AggregationPipeline::Dependencies.new(
          discoverer: adapters[:discoverer], fetcher: adapters[:fetcher],
          manifest_reader: adapters[:manifest_reader],
          channel_filter: channel_filter, stage_filter: stage_filter,
          asset_processor: asset_processor, delta_state: delta_state
        )
        config = AggregationPipeline::Config.new(
          organizations: options[:organizations], channels: options[:channels],
          topic: options[:topic], concurrency: options[:concurrency],
          include_drafts: options[:include_drafts], fail_on_error: false
        )

        pipeline = AggregationPipeline.new(deps)
        result = pipeline.run(config, options[:output_dir])

        print_aggregate_result(result)
        if options[:min_documents].positive? && result.documents.length < options[:min_documents]
          warn "Error: Found #{result.documents.length} documents, minimum is #{options[:min_documents]}"
          exit 1
        end
        exit(result.failed_repos.empty? ? 0 : 1)
      end

      class << self
        private

        def load_manifest(path)
          return nil unless File.exist?(path)

          ChannelManifest.from_file(path)
        end

        def parse_channels(strings)
          (strings || []).map { |s| Channel.parse(s) }
        end

        def resolve_channel_config(cli_source, manifest)
          # 1. CLI --config flag (highest priority)
          return fetch_config(cli_source) if cli_source

          # 2. config: key in manifest
          return fetch_config(manifest.config_source) if manifest&.config_source

          # 3. Directory walk
          found = ConfigLocator.find
          return found if found

          # 4. No config — all channels allowed
          ChannelConfig.empty
        end

        def fetch_config(source)
          if source.start_with?('local:')
            Platform::Local::ConfigFetcher.new.fetch(source)
          elsif source.include?('/')
            Platform::Local::ConfigFetcher.new.fetch("local:#{source}")
          else
            require 'octokit'
            client = PlatformFactory.build_github_client(nil)
            Platform::GitHub::ConfigFetcher.new(client: client).fetch(source)
          end
        end

        def print_package_result(result, dest)
          released = result.released
          puts "Packaged #{released.length} documents → #{dest}/"
          released.each { |doc| puts "  #{doc.id}" }
        end

        def print_publish_result(result)
          puts "Released #{result.released.length}, skipped #{result.skipped.length}, failed #{result.failed.length}"
          result.released.each { |doc| puts "  RELEASED: #{doc.id} (#{doc.version.tag_component})" }
          result.skipped.each { |doc| puts "  SKIPPED: #{doc.id} (unchanged)" }
          result.failed.each { |f| puts "  FAILED: #{f[:document].id} - #{f[:error]}" }
        end

        def print_aggregate_result(result)
          puts "Aggregated #{result.documents.length} documents from #{result.repo_count} repos"
          puts "Index: #{result.channels_found.join(', ')}" unless result.channels_found.empty?
        end
      end
    end
  end
end
