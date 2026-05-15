# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    class ChannelRegistry
      def self.from_yaml(yaml_string)
        data = YAML.safe_load(yaml_string, permitted_classes: [Symbol])
        raise ArgumentError, "Invalid channel registry YAML" unless data.is_a?(Hash)

        channels = parse_channel_list(data["channels"])
        new(channels: channels)
      end

      def self.from_file(path)
        raise ArgumentError, "Channel registry file not found: #{path}" unless File.exist?(path)

        from_yaml(File.read(path))
      end

      def self.all_allowed
        new(channels: [])
      end

      def initialize(channels:)
        @channels = channels.freeze
        @channel_set = channels.to_set
        freeze
      end

      def valid?(channel)
        return true if @channels.empty?

        @channel_set.include?(channel)
      end

      def include?(channel_or_string)
        channel = channel_or_string.is_a?(Channel) ? channel_or_string : Channel.parse(channel_or_string.to_s)
        valid?(channel)
      end

      def channels
        @channels
      end

      def empty?
        @channels.empty?
      end

      private

      def self.parse_channel_list(list)
        return [] unless list

        list.filter_map do |entry|
          case entry
          when Hash   then Channel.parse(entry["name"].to_s)
          when String then Channel.parse(entry)
          end
        end
      end
    end
  end
end
