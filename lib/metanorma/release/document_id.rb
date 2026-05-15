# frozen_string_literal: true

module Metanorma
  module Release
    class DocumentId
      def self.from_raw(raw_identifier)
        normalized = raw_identifier.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
        raise ArgumentError, "Document ID cannot be empty" if normalized.empty?

        new(normalized)
      end

      def self.from_normalized(value)
        raise ArgumentError, "Document ID cannot be empty" if value.nil? || value.strip.empty?

        new(value.to_s.strip)
      end

      def initialize(value)
        @value = value
        freeze
      end

      def to_s
        @value
      end

      def tag_prefix
        @value
      end

      def file_name
        @value
      end

      def eql?(other)
        other.is_a?(self.class) && @value == other.to_s
      end

      def hash
        @value.hash
      end
    end
  end
end
