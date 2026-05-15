# 12 — Aggregation Pipeline

## Summary

Implement the aggregation pipeline orchestrator — the top-level coordinator that discovers repos, fetches releases, filters by channel/stage, processes assets, generates the document index, and delegates to platform-specific adapters via DI.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (RepoRef)
- 06-metadata-extraction (ReleaseMetadata)
- 08-cache-store (CacheStore)
- 09-aggregation-filters-and-delta (ChannelFilter, StageFilter, DeltaState)
- 10-document-index (DocumentIndex, AggregatedDocument)
- 11-asset-processor (AssetProcessor)

## Creates

```
lib/metanorma/release/
├── aggregation_interfaces.rb       # RepoDiscoverer, ReleaseFetcher, ManifestReader, IndexGenerator
└── aggregation_pipeline.rb         # Orchestrator + Result types

spec/aggregation/
└── aggregation_pipeline_spec.rb
```

## Design Principles

### Pipeline has no platform knowledge
All platform-specific behavior (GitHub API, GitLab API, local filesystem) is injected via interfaces. The pipeline calls `discoverer.discover`, `fetcher.fetch`, etc., without knowing what's behind them.

### Parallel repo processing
Repos are processed concurrently (configurable concurrency). Results are collected and merged. Individual repo failures don't stop the pipeline.

### ETag + content-hash two-level caching
1. **ETag level**: If the repo's releases haven't changed (HTTP 304), skip entirely
2. **Content-hash level**: If a release's content hash matches the previous run, skip extraction but include the document in the index (reuses previously extracted file list from DeltaState)

### Document construction is a pure function
`build_document(metadata, files, content_hash, release, repo)` creates an `AggregatedDocument` from its inputs. No side effects.

---

## Interfaces

```ruby
module Metanorma::Release
  module RepoDiscoverer
    def discover                                # => [RepoRef]
  end

  module ReleaseFetcher
    # FetchResult = Struct.new(:releases, :etag, :unchanged?)
    def fetch(repo, etag: nil)                  # => FetchResult
  end

  module ManifestReader
    def read(repo)                              # => [String]? (channel list or nil)
  end

  module IndexGenerator
    def generate(documents, output_dir,         # => String (path to index file)
                 format:, parameters:)
    end
end

FetchResult = Struct.new(:releases, :etag, :unchanged?, keyword_init: true)
RepoReport = Struct.new(:releases, :included, :skipped, :reason, :errors, keyword_init: true)
RepoError = Struct.new(:tag, :message, keyword_init: true)
```

---

## AggregationPipeline

```ruby
class Metanorma::Release::AggregationPipeline
  Dependencies = Struct.new(
    :discoverer, :fetcher, :manifest_reader,
    :channel_filter, :stage_filter,
    :asset_processor, :delta_state,
    keyword_init: true
  )

  Config = Struct.new(
    :organizations, :channels, :topic,
    :concurrency, :include_drafts, :fail_on_error,
    keyword_init: true
  )

  Result = Struct.new(
    :documents, :repo_count, :channels_found,
    :report, :failed_repos,
    keyword_init: true
  )

  def initialize(deps)
    @deps = deps
  end

  def run(config, output_dir)                   # => Result
    # 1. Load delta state
    # 2. Discover repos via discoverer
    # 3. Process repos (parallel, bounded concurrency):
    #    a. Read manifest → check channel overlap (skip if none)
    #    b. Check ETag → skip if unchanged
    #    c. Fetch releases
    #    d. For each release:
    #       - Parse metadata from release body
    #       - Filter by channel + stage
    #       - Check content hash → skip if unchanged (reuse file list)
    #       - Process zip via AssetProcessor
    #       - Build AggregatedDocument
    #       - Mark processed in DeltaState
    #    e. Cleanup stale files for this repo
    # 4. Generate DocumentIndex via IndexGenerator
    # 5. Save delta state
    # 6. Return Result
  end
end
```

### Per-release processing:

```ruby
def process_release(release, repo_key, output_dir)
  metadata = ReleaseMetadata.from_release_body(release.body)
  return skip unless @deps.channel_filter.matches?(metadata)
  return skip unless @deps.stage_filter.matches?(metadata)

  zip_asset = find_zip_asset(release)
  return skip unless zip_asset

  content_hash = extract_content_hash(release.body)

  if @deps.delta_state.processed?(repo_key, release.tag, content_hash)
    # Content unchanged — reuse previous file list
    files = @deps.delta_state.release_files(repo_key, release.tag)
    return build_document(metadata, files_from_names(files), content_hash, release, repo)
  end

  # Content changed or new — extract and process
  result = @deps.asset_processor.process(zip_data, metadata)
  @deps.delta_state.mark_processed(repo_key, release.tag, content_hash, result.files.map(&:path))
  build_document(metadata, result.files, content_hash, release, repo)
end
```

---

## Specs

### Happy path
- 3 repos, each with 2 releases → 6 documents in result
- Documents have correct metadata (id, title, stage, channels)
- Index file written to output_dir
- Delta state saved

### ETag skip
- Repo with matching ETag → skipped, no releases fetched
- Repo in report with reason "skipped: etag unchanged"

### Channel manifest skip
- Repo with no overlapping channels → skipped
- Repo in report with reason "skipped: channel manifest"

### Content-hash dedup
- Release with matching content hash → not re-extracted
- Previous file list reused for AggregatedDocument
- Release counted in report as "skipped" but document appears in result

### Draft filtering
- `include_drafts: false` → draft releases skipped
- `include_drafts: true` → draft releases processed

### Error handling
- Single repo failure → error logged, other repos continue
- Failed repo in result.failed_repos
- Failed repo in report with error details
- `fail_on_error: true` → first repo error raises
- Zip download failure → release skipped with error in report

### Empty cases
- No repos found → empty result (not an error)
- All repos filtered → empty result
- All releases filtered → empty result, report shows all skipped

### Concurrency
- Concurrency = 1 → sequential (reproducible order)
- Concurrency = 4 → parallel (order may vary, but all docs present)

### Integration with DeltaState
- Stale files from previous run cleaned up
- New files added
- Delta state persists across runs

---

## Acceptance

- [ ] Pipeline runs end-to-end with mock adapters
- [ ] Two-level caching (ETag + content hash) works correctly
- [ ] Individual repo failures don't stop pipeline
- [ ] Delta state is saved after successful run
- [ ] Index file written in correct format
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
