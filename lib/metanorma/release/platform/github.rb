# frozen_string_literal: true

begin
  require "octokit"
rescue LoadError
  raise LoadError, "The octokit gem is required for GitHub adapters. Add `gem 'octokit'` to your Gemfile."
end

module Metanorma
  module Release
    module Platform
      module GitHub
        autoload :Publisher, "metanorma/release/platform/github/publisher"
        autoload :TopicDiscoverer, "metanorma/release/platform/github/topic_discoverer"
        autoload :ReleaseFetcher, "metanorma/release/platform/github/release_fetcher"
        autoload :ManifestReader, "metanorma/release/platform/github/manifest_reader"

        def self.cache_store(cache_dir:)
          FileCacheStore.new(cache_dir)
        end
      end
    end
  end
end
