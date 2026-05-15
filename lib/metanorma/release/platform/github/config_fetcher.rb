# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    module Platform
      module GitHub
        class ConfigFetcher
          include Metanorma::Release::ConfigFetcher

          def initialize(client:)
            @client = client
          end

          def fetch(source)
            repo, path = parse_source(source)
            content = @client.contents(repo, path: path)
            return nil unless content

            ChannelConfig.from_yaml(content["content"].unpack("m0").first)
          rescue StandardError
            nil
          end

          private

          def parse_source(source)
            if source.include?("#")
              parts = source.split("#", 2)
              [parts[0], parts[1]]
            else
              [source, "channels.yml"]
            end
          end
        end
      end
    end
  end
end
