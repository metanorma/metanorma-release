# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      class StaticDiscoverer
        include RepoDiscoverer

        def initialize(repos:)
          @repos = repos
        end

        def discover
          @repos
        end
      end
    end
  end
end
