# frozen_string_literal: true

module Metanorma
  module Release
    module FileRouting
      def compute_path(file_name, metadata)
        raise NotImplementedError, "#{self.class} must implement #compute_path"
      end
    end

    class ByDocument
      include FileRouting

      def compute_path(file_name, metadata)
        "#{metadata['id']}/#{file_name}"
      end
    end

    class Flat
      include FileRouting

      def compute_path(file_name, _metadata)
        file_name
      end
    end

    class ByFormat
      include FileRouting

      def compute_path(file_name, _metadata)
        ext = File.extname(file_name).delete_prefix(".")
        "#{ext}/#{file_name}"
      end
    end

    module FileRoutingFactory
      ROUTING_MAP = {
        "by-document" => ByDocument,
        "flat" => Flat,
        "by-format" => ByFormat,
      }.freeze

      def self.from_name(name)
        klass = ROUTING_MAP[name]
        unless klass
          raise ArgumentError,
                "Unknown routing mode: #{name}. Available: #{ROUTING_MAP.keys.join(', ')}"
        end

        klass.new
      end
    end
  end
end
