# frozen_string_literal: true

module Metanorma
  module Release
    module PlatformFactory
      PUBLISHER_REGISTRY = {
        "null" => ->(_opts) { Platform::Null::Publisher.new },
        "local" => ->(opts) { Platform::Local::Publisher.new(output_dir: opts[:output_dir]) }
      }.freeze

      AGGREGATION_REGISTRY = {
        "local" => ->(opts, _token) {
          path = opts[:source].sub("local:", "")
          {
            discoverer: Platform::Local::DirectoryDiscoverer.new(base_path: path),
            fetcher: Platform::Local::Fetcher.new(base_path: path)
          }
        }
      }.freeze

      def self.build_publisher(platform, options)
        factory = PUBLISHER_REGISTRY[platform]
        unless factory
          raise ArgumentError, "Unknown platform: #{platform}. Available: #{PUBLISHER_REGISTRY.keys.join(', ')}"
        end
        factory.call(options)
      end

      def self.build_aggregation_adapters(options)
        source = options[:source]
        if source.start_with?("local:")
          adapters = AGGREGATION_REGISTRY["local"].call(options, options[:token])
          adapters[:manifest_reader] = NullManifestReader.new
          return adapters
        end

        require "octokit"
        client = build_github_client(options[:token])

        discoverer = if options[:repos]
                       repos = options[:repos].map { |r| RepoRef.from_string(r) }
                       StaticDiscoverer.new(repos: repos)
                     else
                       Platform::GitHub::TopicDiscoverer.new(
                         client: client, organizations: options[:organizations], topic: options[:topic]
                       )
                     end

        {
          discoverer: discoverer,
          fetcher: Platform::GitHub::ReleaseFetcher.new(client: client),
          manifest_reader: Platform::GitHub::ManifestReader.new(client: client)
        }
      end

      def self.build_github_client(token)
        require "octokit"
        token ? Octokit::Client.new(access_token: token) : Octokit::Client.new
      end

      class StaticDiscoverer
        include RepoDiscoverer

        def initialize(repos:)
          @repos = repos
        end

        def discover
          @repos
        end
      end

      class NullManifestReader
        include Metanorma::Release::ManifestReader
        def read(_repo) = nil
      end
    end
  end
end
