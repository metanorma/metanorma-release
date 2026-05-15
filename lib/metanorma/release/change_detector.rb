# frozen_string_literal: true

module Metanorma
  module Release
    class ContentHashChangeDetector
      include ChangeDetector

      def initialize(previous_releases:)
        @previous_releases = previous_releases
      end

      def detect(metadata, tag, force: false)
        current = ContentHash.of_directory(metadata.output_dir, base: metadata.file_base_name)
        previous = @previous_releases[tag.to_s]
        changed = force || previous.nil? || !current.eql?(previous)
        ChangeResult.new(changed?: changed, current_hash: current, previous_hash: previous)
      end
    end
  end
end
