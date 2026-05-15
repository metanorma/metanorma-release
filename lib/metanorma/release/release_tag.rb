# frozen_string_literal: true

module Metanorma
  module Release
    class ReleaseTag
      PRE_RELEASE_SUFFIXES = %w[-wd -cd -ds -fd -proposal].freeze

      def self.from(doc_id, version)
        tag = "#{doc_id}/#{version.tag_component}"
        new(tag: tag, pre_release: version.pre_release?)
      end

      def self.create(tag, pre_release:)
        raise ArgumentError, "Tag must contain a slash separator" unless tag.include?("/")

        new(tag: tag, pre_release: pre_release)
      end

      def self.parse(tag)
        raise ArgumentError, "Tag must contain a slash separator" unless tag.include?("/")

        pre = PRE_RELEASE_SUFFIXES.any? { |s| tag.include?(s) }
        new(tag: tag, pre_release: pre)
      end

      def initialize(tag:, pre_release:)
        @tag = tag
        @pre_release = pre_release
        freeze
      end

      def to_s
        @tag
      end

      def pre_release?
        @pre_release
      end

      def eql?(other)
        other.is_a?(self.class) && @tag == other.to_s
      end

      def hash
        @tag.hash
      end
    end
  end
end
