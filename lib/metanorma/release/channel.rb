# frozen_string_literal: true

module Metanorma
  module Release
    class Channel
      attr_reader :name

      def initialize(name)
        @name = name.to_s.strip
        freeze
      end

      def to_s
        @name
      end

      def eql?(other)
        other.is_a?(self.class) && @name == other.name
      end

      def hash
        @name.hash
      end

      def matches?(filter_channels)
        filter_channels.any? { |c| eql?(Channel.new(c)) }
      end

      def self.parse(channel_string)
        new(channel_string.to_s.strip)
      end

      def self.parse_list(strings)
        (strings || []).map { |s| parse(s) }
      end
    end
  end
end
