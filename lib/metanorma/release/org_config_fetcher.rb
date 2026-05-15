# frozen_string_literal: true

module Metanorma
  module Release
    module OrgConfigFetcher
      def fetch(org_identifier)
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end
    end
  end
end
