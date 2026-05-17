# frozen_string_literal: true

module Metanorma
  module Release
    module Filter
      def apply(documents)
        raise NotImplementedError, "#{self.class} must implement #apply"
      end
    end

    module ChangeDetector
      def detect(metadata, tag, force: false)
        raise NotImplementedError, "#{self.class} must implement #detect"
      end
    end

    module Packager
      def package(metadata, canonical_base:)
        raise NotImplementedError, "#{self.class} must implement #package"
      end
    end

    module Publisher
      def publish(tag, artifact, metadata, channels:, force_replace: false)
        raise NotImplementedError, "#{self.class} must implement #publish"
      end
    end

    module RepoDiscoverer
      def discover
        raise NotImplementedError, "#{self.class} must implement #discover"
      end
    end

    module ReleaseFetcher
      def fetch(repo, etag: nil)
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end
    end

    module ManifestReader
      def read(repo)
        raise NotImplementedError, "#{self.class} must implement #read"
      end
    end
  end
end
