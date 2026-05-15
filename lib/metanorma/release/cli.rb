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
        config = parse_package_args(argv)
        result = PackageCommand.new(config).call
        print_package_result(result, config.dest)
        exit(result.failed.empty? ? 0 : 1)
      end

      def run_publish(argv)
        config = parse_publish_args(argv)
        result = PublishCommand.new(config).call
        print_publish_result(result)
        exit(result.failed.empty? ? 0 : 1)
      end

      def run_aggregate(argv)
        config = parse_aggregate_args(argv)
        result = AggregateCommand.new(config).call
        print_aggregate_result(result)
        if config.min_documents.positive? && result.documents.length < config.min_documents
          warn "Error: Found #{result.documents.length} documents, minimum is #{config.min_documents}"
          exit 1
        end
        exit(result.failed_repos.empty? ? 0 : 1)
      end

      class << self
        private

        def parse_package_args(argv)
          options = { output_dir: '_site', dest: 'dist', manifest: 'metanorma.release.yml',
                      config_source: nil }
          OptionParser.new do |opts|
            opts.banner = 'Usage: mn-release package [options]'
            opts.on('--output-dir DIR', 'Compiled docs directory') { |v| options[:output_dir] = v }
            opts.on('--dest DIR', 'Destination for packages') { |v| options[:dest] = v }
            opts.on('--manifest FILE', 'Release manifest file') { |v| options[:manifest] = v }
            opts.on('--config SOURCE', 'Channel config (file path or platform ref)') { |v| options[:config_source] = v }
          end.parse!(argv)
          PackageCommand::Config.new(**options)
        end

        def parse_publish_args(argv)
          options = { output_dir: '_site', platform: 'github', manifest: 'metanorma.release.yml',
                      force: false, force_replace: [], channels: nil, concurrency: 4, token: nil,
                      config_source: nil }
          OptionParser.new do |opts|
            opts.banner = 'Usage: mn-release publish [options]'
            opts.on('--platform NAME', 'github|local') { |v| options[:platform] = v }
            opts.on('--output-dir DIR', 'Compiled docs directory') { |v| options[:output_dir] = v }
            opts.on('--manifest FILE', 'Release manifest file') { |v| options[:manifest] = v }
            opts.on('--force', 'Force release even if unchanged') { |v| options[:force] = v }
            opts.on('--force-replace PAT', 'Glob patterns for force-replace') { |v| options[:force_replace] << v }
            opts.on('--channels CHANS', 'Override channels (comma-separated)') { |v| options[:channels] = v.split(',') }
            opts.on('--concurrency N', Integer) { |v| options[:concurrency] = v }
            opts.on('--token TOKEN', 'Platform auth token') { |v| options[:token] = v }
            opts.on('--config SOURCE', 'Channel config (file path or platform ref)') { |v| options[:config_source] = v }
          end.parse!(argv)
          PublishCommand::Config.new(**options)
        end

        def parse_aggregate_args(argv)
          options = { source: 'github', organizations: [], topic: 'metanorma-release',
                      repos: nil, channels: [], stages: [], output_dir: '_site/cc',
                      file_routing: 'by-document', cache_dir: nil,
                      include_drafts: false, concurrency: 4, min_documents: 0, token: nil }
          OptionParser.new do |opts|
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
          end.parse!(argv)
          AggregateCommand::Config.new(**options)
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
