# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    class ChannelConfig
      def self.from_yaml(yaml_string)
        data = YAML.safe_load(yaml_string, permitted_classes: [Symbol])
        raise ArgumentError, "Invalid channel config YAML" unless data.is_a?(Hash)

        registry = ChannelRegistry.from_yaml(yaml_string)
        defaults = data["defaults"] || {}
        default_visibility = defaults["visibility"] || "public"
        default_channels = parse_channels(defaults["channels"])

        new(registry: registry, default_visibility: default_visibility,
            default_channels: default_channels)
      end

      def self.from_file(path)
        if File.directory?(path)
          channels_yml = File.join(path, "channels.yml")
          raise ArgumentError, "Channel config file not found: #{path}" unless File.exist?(channels_yml)

          return from_file(channels_yml)
        end

        raise ArgumentError, "Channel config file not found: #{path}" unless File.exist?(path)

        from_yaml(File.read(path))
      end

      def self.empty
        new(registry: ChannelRegistry.all_allowed,
            default_visibility: "public", default_channels: [])
      end

      def initialize(registry:, default_visibility:, default_channels:)
        @registry = registry
        @default_visibility = default_visibility
        @default_channels = default_channels.freeze
        freeze
      end

      attr_reader :registry, :default_visibility, :default_channels

      private

      def self.parse_channels(list)
        return [] unless list

        list.map { |c| Channel.parse(c.to_s) }
      end
    end
  end
end
