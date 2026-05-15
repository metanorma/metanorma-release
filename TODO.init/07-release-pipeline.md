# 07 — Release Pipeline

## Summary

Implement the release pipeline orchestrator with its 5 interfaces, concrete implementations for packaging (zip) and change detection (content hash), and the two-phase parallel pipeline.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (DocumentId, ContentHash, Channel)
- 03-stage-version-model (ReleaseTag, DocumentVersion)
- 04-document-type-and-naming (NamingRegistry)
- 05-channel-manifest (ChannelManifest, DocumentReleasePolicy)
- 06-metadata-extraction (ReleaseMetadata, RxlExtractor, DocumentMetadata)

## Creates

```
lib/metanorma/release/
├── interfaces.rb              # Module interfaces: Extractor, Filter, ChangeDetector, Packager, Publisher
├── release_pipeline.rb        # Pipeline orchestrator + Result types
├── zip_packager.rb            # ZipPackager (implements Packager)
└── change_detector.rb         # ContentHashChangeDetector (implements ChangeDetector)

spec/release/
├── release_pipeline_spec.rb
├── zip_packager_spec.rb
└── change_detector_spec.rb
```

## Design Principles

### Interfaces as Ruby modules
Each interface is a module with stub methods that raise `NotImplementedError`. Concrete implementations `include` the module. This provides:
- Documentation of the contract
- Runtime enforcement (missing method → clear error)
- No need for `respond_to?` — if it includes the module, it implements the interface

### Two-phase processing
Phase 1 (read-only): discover → filter → change detection. Parallel, no side effects.
Phase 2 (write): package → publish. Parallel, creates releases.
This separation enables dry-run mode (Phase 1 only) and error recovery.

### Pipeline has no platform knowledge
The pipeline receives all platform-specific behavior through DI. It doesn't know about GitHub, GitLab, or filesystem. It calls `publisher.publish(...)` and trusts the adapter.

---

## Interfaces

```ruby
# lib/metanorma/release/interfaces.rb

module Metanorma::Release
  module Extractor
    def discover(output_dir)                    # => [DocumentMetadata]
    def extract(rxl_path)                       # => DocumentMetadata
  end

  module Filter
    def apply(documents)                        # => [DocumentMetadata]
  end

  module ChangeDetector
    def detect(metadata, tag, force: false)     # => ChangeResult
  end

  module Packager
    def package(metadata, canonical_base:)      # => Artifact
  end

  module Publisher
    def publish(tag, artifact, metadata,        # => PublishResult
               channels:, force_replace: false)
  end
end
```

## Result Types

```ruby
module Metanorma::Release
  ChangeResult = Struct.new(:changed?, :current_hash, :previous_hash, keyword_init: true)
  Artifact = Struct.new(:zip_path, :asset_name, :size, keyword_init: true)
  PublishResult = Struct.new(:tag, :url, :created?, keyword_init: true)

  ReleasedArtifact = Struct.new(:id, :tag, :url, :channels, keyword_init: true)

  ReleaseResult = Struct.new(
    :released, :skipped, :failed, :released_artifacts,
    keyword_init: true
  )
end
```

## ZipPackager

```ruby
class Metanorma::Release::ZipPackager
  include Packager

  def package(metadata, canonical_base:)
    # 1. Create temp zip
    # 2. Add files from metadata.output_dir matching metadata.file_base_name
    # 3. Rename to canonical names (canonical_base.html, canonical_base.pdf, etc.)
    # 4. Return Artifact(zip_path, asset_name, size)
  end
end
```

Uses `Zlib::GzipWriter` + `Zlib::Zip` from stdlib, or `rubyzip` gem for proper zip creation. Start with `rubyzip` as an optional dependency — it's the standard Ruby zip library and avoids the stdlib zip limitations.

### Specs
- Package creates a zip with all document files
- Files inside zip use canonical names (edition suffix removed)
- Only files matching `file_base_name` are included (no stray files)
- Empty output dir → empty zip (valid but empty)
- Zip is valid and extractable

## ContentHashChangeDetector

```ruby
class Metanorma::Release::ContentHashChangeDetector
  include ChangeDetector

  def initialize(previous_releases:)     # Hash: tag_string => ContentHash
  def detect(metadata, tag, force: false)
    current = ContentHash.of_directory(metadata.output_dir, base: metadata.file_base_name)
    previous = previous_releases[tag.to_s]
    changed = force || previous.nil? || !current.eql?(previous)
    ChangeResult.new(changed?: changed, current_hash: current, previous_hash: previous)
  end
end
```

### Specs
- New document (no previous hash) → changed
- Document with same content → not changed
- Document with changed content → changed
- Force flag → always changed
- Previous hash matches current → not changed

## ReleasePipeline

```ruby
class Metanorma::Release::ReleasePipeline
  Dependencies = Struct.new(
    :extractor, :filters, :change_detector,
    :packager, :publisher, :naming_registry,
    :manifest, :channel_override,
    keyword_init: true
  )

  Config = Struct.new(
    :output_dir, :manifest_path, :force, :force_replace_patterns,
    :concurrency, :default_visibility,
    keyword_init: true
  )

  def initialize(deps)
    @deps = deps
  end

  def run(config)                        # => ReleaseResult
    # 1. Discover documents via extractor
    # 2. Apply filters (visibility, pattern, stage)
    # 3. Resolve manifest policy per document
    # 4. Phase 1: change detection (parallel, read-only)
    #    - Skip unchanged documents
    #    - Skip documents failing stage constraint
    # 5. Phase 2: package + publish changed documents (parallel)
    #    - Resolve channels from policy (manifest → override → default)
    #    - Call packager.package → publisher.publish
    # 6. Collect results: released, skipped, failed
    # 7. Return ReleaseResult
  end
end
```

### Channel resolution order:
1. Explicit `channel_override` (from CLI/config) → use these
2. Manifest policy channels → use these
3. Default → `Channel.public("default")`

### Specs

**Happy path**:
- 3 documents, 2 changed, 1 unchanged → 2 released, 1 skipped
- Documents get correct channels from manifest
- Result includes released_artifacts with URLs

**Filtering**:
- Pattern filter excludes matching documents
- Stage filter excludes documents not in stage allow-list
- Empty filters → all documents pass

**Change detection**:
- All documents unchanged, no force → all skipped
- Force flag → all released
- Force replace pattern matches specific documents → those replaced

**Channel resolution**:
- channel_override takes precedence over manifest
- Manifest channels used when no override
- Default channels when no manifest entry

**Error handling**:
- Individual document failure → added to failed, pipeline continues
- Extractor failure → empty result (logged)
- Publisher failure → document in failed, not released

**Edge cases**:
- No documents found → empty result (not an error)
- No manifest → all_public behavior
- Single document → works without parallelism

---

## Acceptance

- [ ] Pipeline runs end-to-end with mock adapters
- [ ] Two-phase processing: change detection before packaging
- [ ] Channel resolution follows precedence order
- [ ] Individual failures don't stop pipeline
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
