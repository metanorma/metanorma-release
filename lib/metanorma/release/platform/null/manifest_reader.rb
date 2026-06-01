# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module Null
        class ManifestReader
          include Metanorma::Release::ManifestReader

          def read(_repo) = nil
        end
      end
    end
  end
end
