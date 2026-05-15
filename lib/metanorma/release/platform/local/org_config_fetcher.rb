# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module Local
        class OrgConfigFetcher
          include Metanorma::Release::OrgConfigFetcher

          def initialize(base_path:)
            @base_path = base_path
          end

          def fetch(org)
            path = File.join(@base_path, org.to_s, ".metanorma")
            return nil unless File.exist?(path)

            OrgConfig.from_file(path)
          end
        end
      end
    end
  end
end
