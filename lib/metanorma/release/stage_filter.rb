# frozen_string_literal: true

module Metanorma
  module Release
    class StageFilter
      def initialize(stages)
        @stages = Set.new(stages.map(&:downcase))
        @all = @stages.empty?
      end

      def matches?(release_metadata)
        return true if @all

        @stages.include?(release_metadata['stage'].to_s.downcase)
      end
    end
  end
end
