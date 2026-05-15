# 09 — Aggregation Filters & Delta State

## Summary

Implement `ChannelFilter`, `StageFilter` (pure logic for filtering releases), and `DeltaState` (content-hash deduplication with stale file cleanup). These are the core filtering and caching mechanisms for the aggregation pipeline.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (Channel, ChannelAudience, RepoRef)
- 03-stage-version-model (DocumentStage)
- 08-cache-store (CacheStore)

## Creates

```
lib/metanorma/release/
├── channel_filter.rb
├── stage_filter.rb
└── delta_state.rb

spec/aggregation/
├── channel_filter_spec.rb
├── stage_filter_spec.rb
└── delta_state_spec.rb
```

## Design Principles

### Filters are pure logic
No I/O, no state. Given a metadata hash and filter config, return true/false. Testable with zero setup.

### DeltaState manages persistence
Content hashes and ETags are persisted via `CacheStore`. DeltaState reads/writes a single JSON blob containing the full state for all repos. Stale file cleanup removes files from releases no longer matching.

### No `send`, no `respond_to?`
Filters receive structured data (hashes with string keys), not arbitrary objects. DeltaState receives a `CacheStore` via constructor injection.

---

## ChannelFilter

```ruby
class Metanorma::Release::ChannelFilter
  # channels: [String] or [] (empty = all channels pass)
  def initialize(channels)
    @channels = channels.map { |c| Channel.parse(c) }
    @all = @channels.empty?
  end

  # Does this release's metadata match any of the filter channels?
  def matches?(release_metadata)        # => bool
  end

  # Quick pre-check: does the manifest have any overlap with filter channels?
  # Returns true if filter is empty (all channels) or if there's any overlap.
  def overlaps?(manifest_channels)      # => bool
  end
end
```

`release_metadata` is a hash with a `channels` key (array of strings like `["public/standards"]`).

`matches?` logic: any of the release's channels overlaps with the filter's channels. Empty filter → all pass.

`overlaps?` logic: any of the manifest channels overlaps with the filter's channels. Used to skip entire repos when their manifest declares no matching channels.

### Specs
- Empty filter → matches everything
- Exact match: filter=["public/standards"], metadata channels=["public/standards"] → true
- Partial match: filter=["public/standards"], metadata channels=["public/standards", "public/reports"] → true
- No match: filter=["members/drafts"], metadata channels=["public/standards"] → false
- Multiple filter channels: any match suffices
- `overlaps?` with matching manifest → true
- `overlaps?` with non-matching manifest → false
- `overlaps?` with empty filter → true

---

## StageFilter

```ruby
class Metanorma::Release::StageFilter
  # stages: [String] or [] (empty = all stages pass)
  def initialize(stages)
    @stages = Set.new(stages.map(&:downcase))
    @all = @stages.empty?
  end

  def matches?(release_metadata)        # => bool
  end
end
```

`release_metadata` is a hash with a `stage` key (string like `"published"` or `"working-draft"`).

### Specs
- Empty stages → matches everything
- Exact match: filter=["published"], metadata stage="published" → true
- Case-insensitive: filter=["Published"], metadata stage="published" → true
- No match: filter=["working-draft"], metadata stage="published" → false
- Multiple stages: any match suffices

---

## DeltaState

```ruby
class Metanorma::Release::DeltaState
  # repo_state: { etag: String?, releases: { tag => { content_hash: String?, files: [String] } } }
  # full_state: { last_run: String, repos: { "owner/repo" => repo_state } }

  def initialize(cache_store, output_dir)
  def load                             # Load state from cache
  def save                             # Save state to cache

  # ETag management
  def etag(repo_key)                   # => String?
  def set_etag(repo_key, etag)         # Store ETag for repo

  # Release dedup
  def processed?(repo_key, tag, content_hash)  # => bool
  def release_files(repo_key, tag)              # => [String]
  def mark_processed(repo_key, tag, content_hash, files)

  # Cleanup
  def cleanup_stale(repo_key, current_tags)     # => Integer (files removed)
end

class Metanorma::Release::NullDeltaState < DeltaState
  def initialize                        # No-op cache
  def load; end
  def save; end
  def processed?(*) = false             # Never reports as processed
  def cleanup_stale(*) = 0              # Never cleans up
end
```

### State format (JSON):

```json
{
  "last_run": "2026-05-14T10:30:00Z",
  "repos": {
    "CalConnect/cc-datetime-explicit": {
      "etag": "abc123",
      "releases": {
        "cc-18011-2018/ed1": {
          "content_hash": "185bd72f...",
          "files": ["cc-18011-2018/cc-18011-2018.html", "cc-18011-2018/cc-18011-2018.pdf"]
        }
      }
    }
  }
}
```

### `cleanup_stale` logic (ported from TS):
1. For each release tag in the repo's state
2. If tag is NOT in `current_tags`
3. Delete all files listed for that tag from `output_dir`
4. Remove the release entry from state
5. Return count of deleted files

### Specs

**ETag management**:
- Get/set ETag for a repo
- Get returns nil for unknown repo
- Set creates repo entry if not exists

**Release dedup**:
- `processed?` returns true when content hash matches
- `processed?` returns false when content hash differs
- `processed?` returns false when no previous state
- `processed?` returns false when nil content hash (always re-process)
- `release_files` returns file list from previous run
- `release_files` returns empty array for unknown release
- `mark_processed` stores hash and file list

**Stale cleanup**:
- Removes files for tags no longer in current set
- Keeps files for tags still in current set
- Returns count of removed files
- Handles missing files gracefully (no error)
- Empty repo state → 0 removed

**Persistence**:
- `load` reads from cache store
- `save` writes to cache store
- `load` + `save` round-trip preserves state
- `load` with invalid JSON → resets to empty state

**NullDeltaState**:
- `processed?` always returns false
- `cleanup_stale` always returns 0
- `load`/`save` are no-ops

---

## Acceptance

- [ ] Filters are pure (no I/O, no state)
- [ ] DeltaState persists to CacheStore
- [ ] Stale cleanup removes orphaned files
- [ ] NullDeltaState is a proper null object
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
