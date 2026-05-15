# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module Local
        autoload :Publisher, "metanorma/release/platform/local/publisher"
        autoload :DirectoryDiscoverer, "metanorma/release/platform/local/directory_discoverer"
        autoload :Fetcher, "metanorma/release/platform/local/fetcher"
      end
    end
  end
end
