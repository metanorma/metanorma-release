# 08 — Cache Store

## Summary

Implement the `CacheStore` interface with file-based and null implementations. This is the persistence layer for delta state, ETags, and content hashes used by the aggregation pipeline.

## Dependencies

- 01-project-scaffold

## Creates

```
lib/metanorma/release/
└── cache_store.rb              # Interface + FileCacheStore + NullCacheStore

spec/aggregation/
└── cache_store_spec.rb
```

## Design

```ruby
module Metanorma::Release
  module CacheStore
    def get(key)                        # => String? (nil if not found)
    def set(key, value)                 # Store value
    def delete(key)                     # Remove key
    def clear                           # Remove all keys
    def keys                            # => [String]
  end
end
```

### FileCacheStore

```ruby
class Metanorma::Release::FileCacheStore
  include CacheStore

  def initialize(directory)             # Directory for cache files
  def get(key)                          # Read from {directory}/{sanitized_key}
  def set(key, value)                   # Write to {directory}/{sanitized_key}
  def delete(key)                       # Delete file
  def clear                             # Delete all files in directory
  def keys                              # List all files in directory
end
```

Key sanitization: replace non-alphanumeric characters with `_` to create safe filenames. The key `etag:CalConnect/cc-datetime` becomes `etag_CalConnect_cc-datetime`.

Auto-creates directory on first write.

### NullCacheStore

Always returns nil from `get`, no-ops for `set`/`delete`. Used when caching is disabled.

### Specs
- `get` returns stored value
- `get` returns nil for missing key
- `set` + `get` round-trip
- `delete` removes key
- `clear` removes all keys
- `keys` lists all stored keys
- Key sanitization handles special characters
- Creates directory if not exists
- NullCacheStore: get returns nil, set is no-op
- Concurrent access safety (basic: no corruption on overlapping writes)

---

## Acceptance

- [ ] FileCacheStore persists across instances (re-reads from disk)
- [ ] NullCacheStore is a proper null object (no state)
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
