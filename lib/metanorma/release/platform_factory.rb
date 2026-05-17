# frozen_string_literal: true

module Metanorma
  module Release
    module PlatformFactory
      PUBLISHER_REGISTRY = {
        "null" => ->(_opts) { Platform::Null::Publisher.new },
        "local" => ->(opts) {
          Platform::Local::Publisher.new(output_dir: opts[:output_dir])
        },
      }.dup

      AGGREGATION_REGISTRY = {
        "local" => lambda { |opts, _token|
          path = opts[:source].sub("local:", "")
          {
            discoverer: Platform::Local::DirectoryDiscoverer.new(base_path: path),
            fetcher: Platform::Local::Fetcher.new(base_path: path),
          }
        },
        "github" => lambda { |opts, token|
          require "octokit"
          client = build_github_client(token)

          discoverer = if opts[:repos]
                         repos = opts[:repos].map { |r| RepoRef.from_string(r) }
                         StaticDiscoverer.new(repos: repos)
                       else
                         Platform::GitHub::TopicDiscoverer.new(
                           client: client, organizations: opts[:organizations], topic: opts[:topic],
                         )
                       end

          {
            discoverer: discoverer,
            fetcher: Platform::GitHub::ReleaseFetcher.new(client: client),
            manifest_reader: Platform::GitHub::ManifestReader.new(client: client),
          }
        },
      }.dup

      def self.build_publisher(platform, options)
        factory = PUBLISHER_REGISTRY[platform]
        unless factory
          raise ArgumentError,
                "Unknown platform: #{platform}. Available: #{PUBLISHER_REGISTRY.keys.join(', ')}"
        end

        factory.call(options)
      end

      def self.build_aggregation_adapters(options)
        source = options[:source]

        if source.start_with?("local:")
          adapters = AGGREGATION_REGISTRY["local"].call(options,
                                                        options[:token])
          adapters[:manifest_reader] = NullManifestReader.new
          return adapters
        end

        AGGREGATION_REGISTRY["github"].call(options, options[:token])
      end

      def self.build_github_client(token)
        require "octokit"
        token ? Octokit::Client.new(access_token: token) : Octokit::Client.new
      end

      def self.register_publisher(name, factory)
        PUBLISHER_REGISTRY[name] = factory
      end

      def self.register_aggregation(name, factory)
        AGGREGATION_REGISTRY[name] = factory
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
