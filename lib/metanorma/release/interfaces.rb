# frozen_string_literal: true

module Metanorma
  module Release
    module Extractor
      def discover(output_dir)
        raise NotImplementedError, "#{self} must implement .discover"
      end
    end

    Release = Struct.new(:tag_name, :body, :prerelease, :draft,
                         :html_url, :published_at, :created_at,
                         :assets, keyword_init: true)
    Asset = Struct.new(:name, :browser_download_url, :size, :data,
                       keyword_init: true)

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
