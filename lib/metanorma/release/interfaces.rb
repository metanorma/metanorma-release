# frozen_string_literal: true

module Metanorma
  module Release
    module Extractor
      def discover(output_dir)
        raise NotImplementedError, "#{self.class} must implement #discover"
      end

      def extract(rxl_path)
        raise NotImplementedError, "#{self.class} must implement #extract"
      end
    end

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

    ChangeResult = Struct.new(:changed?, :current_hash, :previous_hash, keyword_init: true)
    Artifact = Struct.new(:zip_path, :asset_name, :size, keyword_init: true)
    PublishResult = Struct.new(:tag, :url, :created?, keyword_init: true)

    ReleasedArtifact = Struct.new(:id, :tag, :url, :channels, keyword_init: true)

    ReleaseResult = Struct.new(:released, :skipped, :failed, :released_artifacts, keyword_init: true)
  end
end
