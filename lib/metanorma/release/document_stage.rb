# frozen_string_literal: true

module Metanorma
  module Release
    class DocumentStage
      PUBLISHED_NAMES = %w[published in-force approved standard].freeze

      STAGE_ABBREVS = {
        "working-draft" => "wd",
        "committee-draft" => "cd",
        "draft-standard" => "ds",
        "final-draft" => "fd",
        "proposal" => "proposal",
        "informational" => "info",
        "withdrawn" => "withdrawn",
        "cancelled" => "cancelled"
      }.freeze

      ISO_STAGE_MAP = {
        20 => "working-draft",
        30 => "committee-draft",
        40 => "draft-standard",
        50 => "final-draft",
        60 => "published",
        95 => "withdrawn"
      }.freeze

      def self.from_status(status_string)
        raise ArgumentError, "Stage cannot be empty" if status_string.nil? || status_string.strip.empty?

        normalized = status_string.to_s.downcase.strip.gsub(/\s+/, "-")
        new(normalized)
      end

      def self.from_iso_stage(stage, _substage = nil)
        name = ISO_STAGE_MAP[stage.to_i] || ISO_STAGE_MAP.values.first
        new(name)
      end

      def self.published
        new("published")
      end

      def self.working_draft
        new("working-draft")
      end

      def initialize(name)
        @name = name
        freeze
      end

      def to_s
        @name
      end

      def published?
        PUBLISHED_NAMES.include?(@name)
      end

      def draft?
        !published? && @name != "withdrawn" && @name != "cancelled"
      end

      def withdrawn?
        @name == "withdrawn"
      end

      def cancelled?
        @name == "cancelled"
      end

      def tag_suffix
        STAGE_ABBREVS[@name].to_s
      end

      def eql?(other)
        other.is_a?(self.class) && @name == other.to_s
      end

      def hash
        @name.hash
      end
    end
  end
end
