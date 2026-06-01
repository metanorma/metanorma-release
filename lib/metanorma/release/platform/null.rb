# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module Null
        autoload :Publisher, "metanorma/release/platform/null/publisher"
        autoload :ManifestReader,
                 "metanorma/release/platform/null/manifest_reader"
      end
    end
  end
end
