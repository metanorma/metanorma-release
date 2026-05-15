# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module Local
        class ConfigFetcher
          include Metanorma::Release::ConfigFetcher

          def fetch(source)
            path = source.sub(/\Alocal:/, '')
            return nil unless File.exist?(path)

            ChannelConfig.from_file(path)
          end
        end
      end
    end
  end
end
