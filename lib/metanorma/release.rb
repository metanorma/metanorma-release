# frozen_string_literal: true

module Metanorma
  module Release
    require_relative "release/version"

    require "logger"

    class << self
      attr_writer :logger

      def logger
        @logger ||= Logger.new($stderr, level: Logger::WARN)
      end
    end

    # Domain models
    autoload :Publication,           "metanorma/release/publication"
    autoload :PublicationFile,       "metanorma/release/publication"
    autoload :PublicationSource,     "metanorma/release/publication"
    autoload :PublicationSerializer, "metanorma/release/publication_serializer"
    autoload :RxlExtractor,          "metanorma/release/rxl_extractor"
    autoload :Index,                 "metanorma/release/index"
    autoload :Site,                  "metanorma/release/site"
    autoload :Channel,               "metanorma/release/channel"
    autoload :Config,                "metanorma/release/config"
    autoload :ConfigLoader,          "metanorma/release/config"
    autoload :DocumentEntry,         "metanorma/release/config"
    autoload :ChannelResolver,       "metanorma/release/config"
    autoload :ContentHash,           "metanorma/release/content_hash"
    autoload :DependencyValidation,  "metanorma/release/dependency_validation"
    autoload :DocumentFlattener,     "metanorma/release/document_flattener"
    # Strategies
    autoload :SlugStrategy,      "metanorma/release/slug_strategy"
    autoload :EditionSlug,       "metanorma/release/slug_strategy"
    autoload :VersionSlug,       "metanorma/release/slug_strategy"
    autoload :InternetDraftSlug, "metanorma/release/slug_strategy"
    autoload :RfcSlug,           "metanorma/release/slug_strategy"
    autoload :DraftSuffixSlug,   "metanorma/release/slug_strategy"
    autoload :SlugRegistry,      "metanorma/release/slug_strategy"

    # Interfaces & shared types
    autoload :Extractor,         "metanorma/release/interfaces"
    autoload :Release,          "metanorma/release/interfaces"
    autoload :Asset,            "metanorma/release/interfaces"
    autoload :Filter,           "metanorma/release/interfaces"
    autoload :ChangeDetector,   "metanorma/release/interfaces"
    autoload :Packager,         "metanorma/release/interfaces"
    autoload :Publisher,        "metanorma/release/interfaces"
    autoload :RepoDiscoverer,   "metanorma/release/interfaces"
    autoload :ReleaseFetcher,   "metanorma/release/interfaces"
    autoload :ManifestReader,   "metanorma/release/interfaces"

    # Pipeline components
    autoload :RepoRef,                   "metanorma/release/repo_ref"
    autoload :ChangeResult,              "metanorma/release/change_detector"
    autoload :Artifact,                  "metanorma/release/zip_packager"
    autoload :PublishResult,             "metanorma/release/release_pipeline"
    autoload :ReleasedArtifact,          "metanorma/release/release_pipeline"
    autoload :ReleaseResult,             "metanorma/release/release_pipeline"
    autoload :FetchResult,
             "metanorma/release/aggregation_pipeline"
    autoload :RepoReport,
             "metanorma/release/aggregation_pipeline"
    autoload :RepoError,
             "metanorma/release/aggregation_pipeline"
    autoload :ContentHashChangeDetector, "metanorma/release/change_detector"
    autoload :ZipPackager,               "metanorma/release/zip_packager"
    autoload :ReleasePipeline,           "metanorma/release/release_pipeline"
    autoload :AggregationPipeline,
             "metanorma/release/aggregation_pipeline"

    # Filters
    autoload :MetadataFilter, "metanorma/release/channel_filter"

    # Cache
    autoload :CacheStore,     "metanorma/release/cache_store"
    autoload :FileCacheStore, "metanorma/release/cache_store"
    autoload :NullCacheStore, "metanorma/release/cache_store"

    # Asset processing
    autoload :FileRouting,        "metanorma/release/file_routing"
    autoload :ByDocument,         "metanorma/release/file_routing"
    autoload :Flat,               "metanorma/release/file_routing"
    autoload :ByFormat,           "metanorma/release/file_routing"
    autoload :FileRoutingFactory, "metanorma/release/file_routing"
    autoload :AssetProcessor,     "metanorma/release/asset_processor"

    # Delta state
    autoload :DeltaStateManager, "metanorma/release/delta_state"
    autoload :DeltaState,        "metanorma/release/delta_state"
    autoload :NullDeltaState,    "metanorma/release/delta_state"

    # Platform namespace
    autoload :Platform, "metanorma/release/platform"

    # Platform factory
    autoload :PlatformFactory, "metanorma/release/platform_factory"

    # CLI
    autoload :CLI, "metanorma/release/cli"

    # Commands
    autoload :PackageCommand, "metanorma/release/commands/package"
    autoload :ReleaseCommand, "metanorma/release/commands/release_command"
    autoload :AggregateCommand, "metanorma/release/commands/aggregate"
  end
end
