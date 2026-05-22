# frozen_string_literal: true

module Metanorma
  module Release
    class MetadataFilter
      def initialize(channels: [])
        @channels = channels.map { |c| Channel.new(c) }
        @all_channels = @channels.empty?
      end

      def matches?(release_metadata)
        channel_match?(release_metadata)
      end

      def overlaps?(manifest_channels)
        return true if @all_channels

        parsed = manifest_channels.map { |c| Channel.new(c) }
        parsed.any? { |mc| mc.matches?(@channels) }
      end

      private

      def channel_match?(release_metadata)
        return true if @all_channels

        release_channels = (release_metadata["channels"] || []).map do |c|
          Channel.new(c)
        end
        release_channels.any? { |rc| rc.matches?(@channels) }
      end
    end
  end
end
