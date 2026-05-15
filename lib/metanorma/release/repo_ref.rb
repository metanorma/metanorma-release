# frozen_string_literal: true

module Metanorma
  module Release
    class RepoRef
      attr_reader :owner, :repo

      def self.from_string(str)
        parts = str.split('/', 2)
        raise ArgumentError, "Invalid repo reference: #{str}" unless parts.length == 2

        new(owner: parts[0], repo: parts[1])
      end

      def initialize(owner:, repo:)
        @owner = owner
        @repo = repo
        freeze
      end

      def to_s
        "#{owner}/#{repo}"
      end

      def eql?(other)
        other.is_a?(self.class) && owner == other.owner && repo == other.repo
      end

      def hash
        [owner, repo].hash
      end
    end
  end
end
