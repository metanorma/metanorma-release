# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    module Platform
      module GitHub
        class OrgConfigFetcher
          include Metanorma::Release::OrgConfigFetcher

          def initialize(client:)
            @client = client
          end

          def fetch(org)
            content = @client.contents("#{org}/.metanorma", path: "channels.yml")
            return nil unless content

            yaml = content["content"].unpack("m0").first
            OrgConfig.from_yaml(yaml)
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
