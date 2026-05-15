# frozen_string_literal: true

module Metanorma
  module Release
    class Channel
      def self.parse(channel_string)
        parts = channel_string.to_s.strip.split('/', 2)
        if ChannelAudience.values.include?(parts[0])
          new(audience: parts[0], category: parts[1] || 'default')
        else
          new(audience: ChannelAudience::PUBLIC, category: parts[0])
        end
      end

      def self.parse_list(strings)
        (strings || []).map { |s| parse(s) }
      end

      def self.public(category)
        new(audience: ChannelAudience::PUBLIC, category: category)
      end

      def self.members(category)
        new(audience: ChannelAudience::MEMBERS, category: category)
      end

      def self.internal(category)
        new(audience: ChannelAudience::INTERNAL, category: category)
      end

      attr_reader :audience, :category

      def initialize(audience:, category:)
        @audience = audience
        @category = category
        freeze
      end

      def to_s
        "#{audience}/#{category}"
      end

      def public?
        audience == ChannelAudience::PUBLIC
      end

      def members?
        audience == ChannelAudience::MEMBERS
      end

      def matches?(filter_channels)
        filter_channels.any? { |c| eql?(Channel.parse(c)) }
      end

      def eql?(other)
        other.is_a?(self.class) && audience == other.audience && category == other.category
      end

      def hash
        [audience, category].hash
      end
    end
  end
end
