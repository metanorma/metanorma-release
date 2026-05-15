# frozen_string_literal: true

module Metanorma
  module Release
    class ChannelFilter
      def initialize(channels)
        @channels = channels.map { |c| Channel.parse(c) }
        @all = @channels.empty?
      end

      def matches?(release_metadata)
        return true if @all

        release_channels = (release_metadata["channels"] || []).map { |c| Channel.parse(c) }
        release_channels.any? { |rc| @channels.any? { |fc| fc.eql?(rc) } }
      end

      def overlaps?(manifest_channels)
        return true if @all

        parsed = manifest_channels.map { |c| Channel.parse(c) }
        parsed.any? { |mc| @channels.any? { |fc| fc.eql?(mc) } }
      end
    end
  end
end
