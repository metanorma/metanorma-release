# frozen_string_literal: true

module Metanorma
  module Release
    ChangeResult = Struct.new(:changed?, :current_hash, :previous_hash,
                              keyword_init: true)

    class ContentHashChangeDetector
      include ChangeDetector

      def initialize(previous_releases:, output_dir: ".")
        @previous_releases = previous_releases
        @output_dir = output_dir
      end

      def detect(publication, tag, force: false)
        current = publication.content_hash(from_directory: @output_dir)
        previous = @previous_releases[tag.to_s]
        changed = force || previous.nil? || !current.eql?(previous)
        ChangeResult.new(changed?: changed, current_hash: current,
                         previous_hash: previous)
      end
    end
  end
end
