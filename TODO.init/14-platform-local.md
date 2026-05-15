# 14 — Local & Null Platform Adapters

## Summary

Implement filesystem-based adapters for local/offline use: `Publisher` (writes zip + metadata to disk), `DirectoryDiscoverer` (scans directory for release packages), `LocalFetcher` (reads zip + metadata from disk). Also `NullPublisher` for dry-run mode.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (RepoRef)
- 06-metadata-extraction (ReleaseMetadata)
- 07-release-pipeline (interfaces: Publisher)
- 12-aggregation-pipeline (interfaces: RepoDiscoverer, ReleaseFetcher)

## Creates

```
lib/metanorma/release/platform/
├── local/
│   ├── publisher.rb
│   ├── directory_discoverer.rb
│   └── fetcher.rb
├── null/
│   └── publisher.rb
├── local.rb                    # require "metanorma/release/platform/local"
└── null.rb                     # require "metanorma/release/platform/null"

spec/platform/local/
├── publisher_spec.rb
├── directory_discoverer_spec.rb
└── fetcher_spec.rb
spec/platform/null/
└── publisher_spec.rb
```

## Design Principles

### Local publisher enables offline distribution
A user compiles a Metanorma document, runs `mn-release package`, and gets a zip + metadata file on disk. No GitHub, no GitLab, no API. The zip can be shared via email, USB, file server, etc.

### Local aggregation enables air-gapped workflows
A user places multiple zip + metadata pairs in a directory, runs `mn-release aggregate --source local:/path/`, and gets the same `index.json` output as the CI version. The publishing site can be built entirely offline.

### Null publisher enables dry-run
The release pipeline runs with `NullPublisher` for local packaging without any side effects. Discover → extract → package → log results → stop. No files written to disk (beyond the temp zip).

---

## Local::Publisher

```ruby
class Metanorma::Release::Platform::Local::Publisher
  include Metanorma::Release::Publisher

  def initialize(output_dir:)
  def publish(tag, artifact, metadata, channels:, force_replace: false)
    # 1. Compute output path: {output_dir}/{asset_name}
    # 2. If force_replace and file exists: delete
    # 3. Copy zip from artifact.zip_path to output path
    # 4. Write sidecar metadata: {output_dir}/{base_name}.meta.json
    # 5. Return PublishResult(tag: tag, url: "file://{path}", created?: true)
  end
end
```

Sidecar metadata format (`.meta.json`):
```json
{
  "version": 1,
  "id": "cc-18011",
  "title": "...",
  "edition": "1",
  "stage": "published",
  "channels": ["public/standards"],
  "formats": ["html", "pdf", "xml", "rxl"],
  "contentHash": "abc123..."
}
```

### Specs
- Writes zip to output directory
- Writes sidecar metadata alongside zip
- force_replace deletes existing file
- Creates output directory if missing
- PublishResult url is file:// URI
- Metadata JSON is valid and round-trips through ReleaseMetadata

---

## Local::DirectoryDiscoverer

```ruby
class Metanorma::Release::Platform::Local::DirectoryDiscoverer
  include Metanorma::Release::RepoDiscoverer

  def initialize(base_path:)
  def discover
    # 1. Scan base_path for directories
    # 2. Each directory = a "repo" (contains release zips + metadata)
    # 3. Return [RepoRef] where owner = "local", repo = directory name
  end
end
```

### Specs
- Scans directory for subdirectories → RepoRef list
- Empty directory → empty array
- Non-existent directory → empty array
- Ignores files (only directories)
- RepoRef: owner="local", repo=directory_name

---

## Local::Fetcher

```ruby
class Metanorma::Release::Platform::Local::Fetcher
  include Metanorma::Release::ReleaseFetcher

  def initialize(base_path:)
  def fetch(repo, etag: nil)
    # 1. Scan repo directory for zip + .meta.json pairs
    # 2. For each pair, construct a "release" with:
    #    - tag from metadata
    #    - body with embedded metadata
    #    - assets with file:// URLs
    # 3. Return FetchResult(releases:, etag: nil, unchanged?: false)
    #    (ETag not supported for local — always re-scans)
  end
end
```

The fetcher converts local files into the same format as the GitHub release fetcher, so the aggregation pipeline works identically.

### Specs
- Finds zip + metadata pairs in directory
- Constructs releases with correct metadata
- File URLs point to actual files on disk
- Missing metadata for a zip → skip with warning
- Empty directory → empty FetchResult
- Multiple zips → multiple releases

---

## Null::Publisher

```ruby
class Metanorma::Release::Platform::Null::Publisher
  include Metanorma::Release::Publisher

  def publish(tag, artifact, metadata, channels:, force_replace: false)
    # Log the publish action
    # Return PublishResult(tag: tag, url: "null://", created?: true)
  end
end
```

### Specs
- publish returns valid PublishResult
- No files written to disk
- No errors raised

---

## Acceptance

- [ ] Local publisher writes zip + metadata to disk
- [ ] Local discoverer scans directories for release packages
- [ ] Local fetcher reads zip + metadata and converts to release format
- [ ] Null publisher produces no side effects
- [ ] Aggregation pipeline works with local adapters end-to-end
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
