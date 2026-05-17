# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module Null
        class Publisher
          include Metanorma::Release::Publisher

          def publish(tag, _artifact, _metadata, channels:,
force_replace: false)
            PublishResult.new(tag: tag.to_s, url: "null://", created?: true)
          end
        end
      end
    end
  end
end
