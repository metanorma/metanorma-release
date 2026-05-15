# frozen_string_literal: true

module Metanorma
  module Release
    class DocumentVersion
      attr_reader :edition, :stage

      def self.from(edition, stage)
        ed = edition.to_s.strip
        ed = '0' if ed.empty?
        new(edition: ed, stage: stage)
      end

      def self.published(edition:)
        new(edition: edition.to_s.strip, stage: DocumentStage.published)
      end

      def initialize(edition:, stage:)
        @edition = edition
        @stage = stage
        freeze
      end

      def tag_component
        base = "ed#{edition}"
        return base if stage.published?

        suffix = stage.tag_suffix
        suffix.empty? ? base : "#{base}-#{suffix}"
      end

      def pre_release?
        stage.draft?
      end

      def file_name(doc_id)
        base = "#{doc_id}-#{tag_component}"
        "#{base}.zip"
      end

      def eql?(other)
        other.is_a?(self.class) && edition == other.edition && stage.eql?(other.stage)
      end

      def hash
        [edition, stage].hash
      end
    end
  end
end
