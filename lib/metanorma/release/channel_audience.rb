# frozen_string_literal: true

module Metanorma
  module Release
    module ChannelAudience
      PUBLIC = 'public'
      MEMBERS = 'members'
      INTERNAL = 'internal'

      ALL = [PUBLIC, MEMBERS, INTERNAL].freeze

      def self.values
        ALL
      end

      def self.from_string(raw)
        normalized = raw.to_s.downcase.strip
        return normalized if ALL.include?(normalized)

        raise ArgumentError, "Unknown audience: #{raw.inspect}. Expected one of: #{ALL.join(', ')}"
      end
    end
  end
end
