# frozen_string_literal: true

module Metanorma
  module Release
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

    module IndexGenerator
      def generate(documents, output_dir, format:, parameters:)
        raise NotImplementedError, "#{self.class} must implement #generate"
      end
    end

    FetchResult = Struct.new(:releases, :etag, :unchanged?, keyword_init: true)
    RepoReport  = Struct.new(:releases, :included, :skipped, :reason, :errors, keyword_init: true)
    RepoError   = Struct.new(:tag, :message, keyword_init: true)
  end
end
