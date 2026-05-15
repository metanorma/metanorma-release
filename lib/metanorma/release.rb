# frozen_string_literal: true

module Metanorma
  module Release
    VERSION = '0.2.0'

    # Domain value objects
    autoload :ChannelAudience, 'metanorma/release/channel_audience'
    autoload :Channel,         'metanorma/release/channel'
    autoload :ChannelRegistry, 'metanorma/release/channel_registry'
    autoload :ChannelConfig,   'metanorma/release/channel_config'
    autoload :ConfigLocator,   'metanorma/release/config_locator'
    autoload :ContentHash,     'metanorma/release/content_hash'
    autoload :DocumentId,      'metanorma/release/document_id'
    autoload :DocumentStage,   'metanorma/release/document_stage'
    autoload :DocumentType,    'metanorma/release/document_type'
    autoload :DocumentVersion, 'metanorma/release/document_version'
    autoload :ReleaseTag,      'metanorma/release/release_tag'
    autoload :RepoRef,         'metanorma/release/repo_ref'

    # Domain strategies
    autoload :NamingStrategy,      'metanorma/release/naming_strategy'
    autoload :EditionNaming,       'metanorma/release/naming_strategy'
    autoload :VersionNaming,       'metanorma/release/naming_strategy'
    autoload :InternetDraftNaming, 'metanorma/release/naming_strategy'
    autoload :RfcNaming,           'metanorma/release/naming_strategy'
    autoload :DraftSuffixNaming,   'metanorma/release/naming_strategy'
    autoload :NamingRegistry,      'metanorma/release/naming_strategy'

    # Manifest & policy
    autoload :ChannelManifest,       'metanorma/release/channel_manifest'
    autoload :DocumentReleasePolicy, 'metanorma/release/channel_manifest'
    autoload :ManifestEntry,         'metanorma/release/channel_manifest'

    # Metadata
    autoload :DocumentMetadata, 'metanorma/release/document_metadata'
    autoload :ReleaseMetadata,  'metanorma/release/release_metadata'
    autoload :RxlExtractor,     'metanorma/release/rxl_extractor'

    # Interfaces
    autoload :Extractor,        'metanorma/release/interfaces'
    autoload :Filter,           'metanorma/release/interfaces'
    autoload :ChangeDetector,   'metanorma/release/interfaces'
    autoload :Packager,         'metanorma/release/interfaces'
    autoload :Publisher,        'metanorma/release/interfaces'

    # Pipeline components
    autoload :ChangeResult,              'metanorma/release/interfaces'
    autoload :Artifact,                  'metanorma/release/interfaces'
    autoload :PublishResult,             'metanorma/release/interfaces'
    autoload :ReleasedArtifact,          'metanorma/release/interfaces'
    autoload :ReleaseResult,             'metanorma/release/interfaces'
    autoload :ContentHashChangeDetector, 'metanorma/release/change_detector'
    autoload :ZipPackager,               'metanorma/release/zip_packager'
    autoload :ReleasePipeline,           'metanorma/release/release_pipeline'

    # Cache
    autoload :CacheStore,      'metanorma/release/cache_store'
    autoload :FileCacheStore,  'metanorma/release/cache_store'
    autoload :NullCacheStore,  'metanorma/release/cache_store'

    # Aggregation filters
    autoload :ChannelFilter,   'metanorma/release/channel_filter'
    autoload :ConfigFetcher,   'metanorma/release/config_fetcher'
    autoload :StageFilter,   'metanorma/release/stage_filter'
    autoload :DeltaState,    'metanorma/release/delta_state'
    autoload :NullDeltaState, 'metanorma/release/delta_state'

    # Document index
    autoload :DocumentFile,       'metanorma/release/document_index'
    autoload :DocumentSource,     'metanorma/release/document_index'
    autoload :IndexParameters,    'metanorma/release/document_index'
    autoload :IndexSummary,       'metanorma/release/document_index'
    autoload :AggregatedDocument, 'metanorma/release/document_index'
    autoload :DocumentIndex,      'metanorma/release/document_index'

    # Asset processing
    autoload :FileRouting,       'metanorma/release/file_routing'
    autoload :ByDocument,        'metanorma/release/file_routing'
    autoload :Flat,              'metanorma/release/file_routing'
    autoload :ByFormat,          'metanorma/release/file_routing'
    autoload :FileRoutingFactory, 'metanorma/release/file_routing'
    autoload :AssetProcessor,    'metanorma/release/asset_processor'

    # Aggregation
    autoload :RepoDiscoverer,    'metanorma/release/aggregation_interfaces'
    autoload :ReleaseFetcher,    'metanorma/release/aggregation_interfaces'
    autoload :ManifestReader,    'metanorma/release/aggregation_interfaces'
    autoload :IndexGenerator,    'metanorma/release/aggregation_interfaces'
    autoload :FetchResult,       'metanorma/release/aggregation_interfaces'
    autoload :RepoReport,        'metanorma/release/aggregation_interfaces'
    autoload :RepoError,         'metanorma/release/aggregation_interfaces'
    autoload :AggregationPipeline, 'metanorma/release/aggregation_pipeline'

    # Platform namespace
    autoload :Platform, 'metanorma/release/platform'

    # Platform factory
    autoload :PlatformFactory, 'metanorma/release/platform_factory'

    # Relaton enrichment
    autoload :RelatonEnricher, 'metanorma/release/relaton_enricher'

    # CLI & Rake
    autoload :CLI, 'metanorma/release/cli'
    autoload :RakeTasks, 'metanorma/release/rake_tasks'
  end
end
