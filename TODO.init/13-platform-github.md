# 13 — GitHub Platform Adapters

## Summary

Implement the GitHub-specific adapters: `Publisher` (create/update releases with assets), `TopicDiscoverer` (search repos by topic), `ReleaseFetcher` (list releases with ETag support), `ManifestReader` (fetch file contents), and `CacheStore` (file-based, for use with `actions/cache`).

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (RepoRef, Channel, ContentHash)
- 06-metadata-extraction (ReleaseMetadata)
- 07-release-pipeline (interfaces: Publisher)
- 08-cache-store (FileCacheStore)
- 11-asset-processor (FileRouting)
- 12-aggregation-pipeline (interfaces: RepoDiscoverer, ReleaseFetcher, ManifestReader)

## Creates

```
lib/metanorma/release/platform/
├── github/
│   ├── publisher.rb
│   ├── topic_discoverer.rb
│   ├── release_fetcher.rb
│   ├── manifest_reader.rb
│   └── cache_store.rb
└── github.rb                   # require "metanorma/release/platform/github"

spec/platform/github/
├── publisher_spec.rb
├── topic_discoverer_spec.rb
├── release_fetcher_spec.rb
├── manifest_reader_spec.rb
└── cache_store_spec.rb
spec/fixtures/
└── github/
    ├── search_repos.json
    ├── releases.json
    └── manifest.yml
```

## Design Principles

### Octokit dependency is optional
The gem does not require `octokit` in the gemspec. Users who want GitHub adapters add `gem "octokit"` to their Gemfile. The adapter file checks at load time and raises a helpful message if missing.

### HTTP fixtures for testing
No live API calls in specs. All GitHub adapter specs use recorded JSON fixtures. This makes specs fast, deterministic, and offline-capable.

### ETag support for release fetching
GitHub supports conditional requests via ETags. When the response hasn't changed, the fetcher returns `unchanged: true` without processing any releases.

---

## GitHub::Publisher

```ruby
class Metanorma::Release::Platform::GitHub::Publisher
  include Metanorma::Release::Publisher

  def initialize(client:)                       # Octokit::Client
  def publish(tag, artifact, metadata, channels:, force_replace: false)
    # 1. If force_replace: delete existing release + tag
    # 2. Check for existing release by tag
    # 3. If exists and not force: update release body (update hash)
    # 4. If new: create release with metadata body + content-hash
    # 5. Upload zip asset
    # 6. Return PublishResult(tag, url, created?)
  end
end
```

Release body format:
```
content-hash:{sha256_hex}
<!-- mn-release-metadata
{json_metadata}
-->
```

### Specs
- Create new release: calls GitHub API create
- Upload asset: calls upload_release_asset
- Update existing release: calls update_release
- Force replace: deletes old release, creates new
- Force replace: deletes old tag ref
- Metadata embedded in release body
- Content hash in first line of body

---

## GitHub::TopicDiscoverer

```ruby
class Metanorma::Release::Platform::GitHub::TopicDiscoverer
  include Metanorma::Release::RepoDiscoverer

  def initialize(client:, organizations:, topic:)
  def discover
    # Search: "topic:{topic} org:{org}" for each organization
    # Paginate if > 100 results
    # Return [RepoRef]
  end
end
```

### Specs
- Single org, multiple repos → correct RepoRef list
- Multiple orgs → combined results
- No results → empty array
- Pagination: handles > 100 results
- Uses GitHub Search API with topic qualifier

---

## GitHub::ReleaseFetcher

```ruby
class Metanorma::Release::Platform::GitHub::ReleaseFetcher
  include Metanorma::Release::ReleaseFetcher

  def initialize(client:)
  def fetch(repo, etag: nil)
    # List releases for repo with ETag conditional request
    # If 304 Not Modified → return FetchResult(unchanged: true)
    # Parse releases into normalized format
    # Return FetchResult(releases:, etag:, unchanged: false)
  end

  # Release struct consumed by pipeline
  GitHubRelease = Struct.new(:tag_name, :body, :prerelease, :draft,
                              :html_url, :published_at, :created_at,
                              :assets, keyword_init: true)
  GitHubAsset = Struct.new(:name, :browser_download_url, :size, keyword_init: true)
end
```

### Specs
- Fetch releases for repo → array of GitHubRelease
- ETag match → FetchResult(unchanged: true, releases: [])
- ETag mismatch → FetchResult with releases and new ETag
- Draft releases included when present
- Assets parsed correctly
- Empty repo (no releases) → FetchResult(releases: [])
- Pagination: handles > 30 releases per page

---

## GitHub::ManifestReader

```ruby
class Metanorma::Release::Platform::GitHub::ManifestReader
  include Metanorma::Release::ManifestReader

  def initialize(client:)
  def read(repo)
    # Fetch metanorma.release.yml from repo's default branch
    # Parse YAML → extract channels list
    # Return [String] or nil (file not found)
  end
end
```

### Specs
- Manifest found → returns channel list from YAML
- Manifest not found → returns nil (not an error)
- Invalid YAML → logs warning, returns nil
- Uses Contents API to fetch file

---

## GitHub::CacheStore

Uses the generic `FileCacheStore` from task 08, no separate implementation needed. Just a convenience factory:

```ruby
module Metanorma::Release::Platform::GitHub
  def self.cache_store(cache_dir:)
    FileCacheStore.new(cache_dir)
  end
end
```

---

## Acceptance

- [ ] All adapters work with recorded fixtures (no live API calls in specs)
- [ ] Publisher creates/releases with correct metadata format
- [ ] TopicDiscoverer handles pagination
- [ ] ReleaseFetcher supports ETag conditional requests
- [ ] ManifestReader handles missing file gracefully
- [ ] Octokit dependency is optional (load-time check)
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
