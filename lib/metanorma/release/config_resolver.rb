# frozen_string_literal: true

module Metanorma
  module Release
    module ConfigResolver
      def resolve_channel_config(cli_source, manifest)
        return fetch_config(cli_source) if cli_source
        return fetch_config(manifest.config_source) if manifest&.config_source

        found = ConfigLocator.find
        return found if found

        ChannelConfig.empty
      end

      def load_manifest(path)
        return nil unless path && File.exist?(path)

        ChannelManifest.from_file(path)
      end

      private

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
    end
  end
end
