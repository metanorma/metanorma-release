# frozen_string_literal: true

module Metanorma
  module Release
    module ConfigFetcher
      def fetch(source)
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end
    end
  end
end
