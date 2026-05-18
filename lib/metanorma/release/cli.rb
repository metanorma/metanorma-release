# frozen_string_literal: true

require "thor"

module Metanorma
  module Release
    class CLI < Thor
      def self.exit_on_failure?
        true
      end

      class PipelineError < Thor::Error; end

      desc "package", "Package compiled documents"
      option :output_dir, type: :string, default: "_site",
                          desc: "Compiled docs directory"
      option :dest, type: :string, default: "dist",
                    desc: "Destination for packages"
      option :manifest, type: :string, default: "metanorma.release.yml",
                        desc: "Release manifest file"
      option :config, type: :string, desc: "Config file"

      def package
        config = PackageCommand::Config.new(
          output_dir: options[:output_dir],
          dest: options[:dest],
          manifest: options[:manifest],
          config_source: options[:config],
        )
        result = PackageCommand.new(config).call
        print_package_result(result, config.dest)
        raise PipelineError, format_failures(result) unless result.failed.empty?
      end

      desc "release", "Package and release documents"
      option :platform, type: :string, default: "github",
                        desc: "Publishing platform (github|local)"
      option :output_dir, type: :string, default: "_site",
                          desc: "Compiled docs directory"
      option :manifest, type: :string, default: "metanorma.release.yml",
                        desc: "Release manifest file"
      option :force, type: :boolean, default: false,
                     desc: "Force release even if unchanged"
      option :force_replace, type: :array, default: [],
                             desc: "Glob patterns for force-replace"
      option :channels, type: :array, desc: "Override channels"
      option :concurrency, type: :numeric, default: 4
      option :token, type: :string, desc: "Platform auth token"
      option :config, type: :string, desc: "Config file"

      def release
        config = ReleaseCommand::Config.new(
          output_dir: options[:output_dir],
          platform: options[:platform],
          manifest: options[:manifest],
          force: options[:force],
          force_replace: options[:force_replace],
          channels: options[:channels],
          concurrency: options[:concurrency],
          token: options[:token],
          config_source: options[:config],
        )
        result = ReleaseCommand.new(config).call
        print_publish_result(result)
        raise PipelineError, format_failures(result) unless result.failed.empty?
      end

      desc "aggregate", "Aggregate released documents"
      option :source, type: :string, default: "github",
                      desc: "Source (github|local:PATH)"
      option :organizations, type: :array, default: [],
                             desc: "Organizations to discover"
      option :topic, type: :string, default: "metanorma-release",
                     desc: "Repository topic"
      option :repos, type: :array, desc: "Explicit repo list"
      option :channels, type: :array, default: [],
                        desc: "Filter channels"
      option :stages, type: :array, default: [],
                      desc: "Filter stages"
      option :output_dir, type: :string, default: "_site/cc",
                          desc: "Output directory"
      option :file_routing, type: :string, default: "by-document",
                            desc: "File routing (by-document|flat|by-format)"
      option :cache_dir, type: :string, desc: "Cache directory"
      option :data_dir, type: :string, desc: "Write flattened documents.json for site generators"
      option :include_drafts, type: :boolean, default: false,
                              desc: "Include draft releases"
      option :concurrency, type: :numeric, default: 4
      option :min_documents, type: :numeric, default: 0,
                             desc: "Minimum required documents"
      option :token, type: :string, desc: "Platform auth token"
      option :config, type: :string, desc: "Config file (default: metanorma.aggregate.yml)"

      def aggregate
        config = AggregateCommand.build_config(
          source: options[:source],
          organizations: options[:organizations],
          topic: options[:topic],
          repos: options[:repos],
          channels: options[:channels],
          stages: options[:stages],
          output_dir: options[:output_dir],
          file_routing: options[:file_routing],
          cache_dir: options[:cache_dir],
          data_dir: options[:data_dir],
          include_drafts: options[:include_drafts],
          concurrency: options[:concurrency],
          min_documents: options[:min_documents],
          token: options[:token],
          create_zip: nil,
          config: options[:config],
        )
        result = AggregateCommand.new(config).call
        print_aggregate_result(result)

        if config.min_documents.positive? && result.publications.length < config.min_documents
          raise PipelineError,
                "Found #{result.publications.length} documents, minimum is #{config.min_documents}"
        end

        unless result.failed_repos.empty?
          raise PipelineError,
                format_repo_failures(result)
        end
      end

      private

      def print_package_result(result, dest)
        released = result.released
        puts "Packaged #{released.length} documents → #{dest}/"
        released.each { |pub| puts "  #{pub.slug}" }
      end

      def print_publish_result(result)
        puts "Released #{result.released.length}, skipped #{result.skipped.length}, failed #{result.failed.length}"
        result.released.each do |pub|
          puts "  RELEASED: #{pub.slug} (ed#{pub.edition})"
        end
        result.skipped.each { |pub| puts "  SKIPPED: #{pub.slug} (unchanged)" }
        result.failed.each do |f|
          puts "  FAILED: #{f[:document].slug} - #{f[:error]}"
        end
      end

      def print_aggregate_result(result)
        puts "Aggregated #{result.publications.length} documents from #{result.repo_count} repos"
        puts "Channels: #{result.channels_found.join(', ')}" unless result.channels_found.empty?
      end

      def format_failures(result)
        result.failed.map do |f|
          "#{f[:document].slug}: #{f[:error]}"
        end.join("\n")
      end

      def format_repo_failures(result)
        result.failed_repos.map { |r| "#{r.tag}: #{r.message}" }.join("\n")
      end
    end
  end
end
