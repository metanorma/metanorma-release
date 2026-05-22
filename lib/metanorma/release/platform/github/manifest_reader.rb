# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    module Platform
      module GitHub
        class ManifestReader
          include Metanorma::Release::ManifestReader

          def initialize(client:)
            @client = client
          end

          def read(repo)
            content = @client.contents(repo.to_s, path: "metanorma.release.yml")
            return nil unless content

            yaml = content["content"].unpack1("m0")
            parsed = YAML.safe_load(yaml, permitted_classes: [Symbol])
            return nil unless parsed.is_a?(Hash)

            channels = Array(parsed["channels"])
            Array(parsed["documents"]).each { |doc| channels.concat(Array(doc["channels"])) }
            channels.map(&:to_s).uniq
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
