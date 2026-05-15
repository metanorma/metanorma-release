# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module Local
        class DirectoryDiscoverer
          include Metanorma::Release::RepoDiscoverer

          def initialize(base_path:)
            @base_path = base_path
          end

          def discover
            return [] unless Dir.exist?(@base_path)

            Dir.children(@base_path).filter_map do |entry|
              full = File.join(@base_path, entry)
              RepoRef.new(owner: "local", repo: entry) if File.directory?(full)
            end
          end
        end
      end
    end
  end
end
