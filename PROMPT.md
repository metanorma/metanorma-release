# PROMPT.md — metanorma-release Implementation Guide

This file provides guidance to AI agents and developers implementing the `metanorma-release` gem. Read it before starting any task. Re-read it when in doubt.

## What This Gem Does

`metanorma-release` manages the full release lifecycle of Metanorma documents:

1. **Release** (producer side): Discover compiled documents → extract metadata from RXL → detect changes → package as zip → publish to a platform (GitHub Releases, GitLab Releases, local filesystem)
2. **Aggregate** (consumer side): Discover repos → fetch published releases → filter by channel/stage → extract zip assets → generate `index.json` + file tree

It works locally (offline, no CI) and in CI (GitHub Actions, GitLab CI, Bitbucket). The output is platform-agnostic: a directory containing `index.json` and a tree of document files. Any site generator (Jekyll, Hugo, Vite, handcrafted) consumes that output independently.

## Implementation Tasks

Detailed task specifications are in `TODO.init/01-*.md` through `TODO.init/16-*.md`. Execute them in numerical order. Each task file specifies: files to create, specs to write, design decisions, and acceptance criteria. Do not skip ahead — earlier tasks are dependencies for later ones.

Before starting a task, read the task file completely. After completing a task, verify all acceptance criteria pass.

## Architecture

### Dependency Flow (unidirectional, no cycles)

```
domain/  →  release/  →  platform/
         →  aggregation/ →  platform/
                          →  cli/
```

- `domain/` has zero knowledge of pipelines, platforms, or CLI
- Pipelines depend on domain + interfaces, not on platform implementations
- Platform adapters depend on interfaces + domain, not on pipelines
- CLI depends on pipelines + platform adapters, wiring them together

### Key Patterns

**Value Objects**: Immutable, frozen, value-based equality. Created via `self.from_*` factory methods, never mutated. Examples: `DocumentId`, `Channel`, `ReleaseTag`, `ContentHash`.

**Strategy Pattern**: Pluggable algorithms behind a common interface. Resolved via registry (Open/Closed). Examples: `NamingStrategy` (5 implementations), `FileRouting` (3 implementations).

**Pipeline with DI**: Orchestrators receive all dependencies through constructors. No global state, no service locators, no `send`, no `respond_to?`. Pipelines compose domain objects and delegate to injected adapters.

**Null Object**: When a feature is disabled, inject a null implementation instead of adding conditional checks. Examples: `NullDeltaState`, `NullPublisher`, `NullCacheStore`.

**Result Types**: Pipelines return frozen Structs (`ReleaseResult`, `AggregationResult`). Errors are collected, not raised. Callers inspect `result.failed` to decide whether to abort.

## Hard Rules

### Never use `send` or `__send__`

It breaks encapsulation by calling private methods from outside. If you need a behavior, make it public or restructure the design. If you need polymorphic dispatch, use the Strategy pattern with a common interface.

### Never use `respond_to?`

It probes an object's internals instead of trusting the type contract. If an object includes `Metanorma::Release::Publisher`, it implements `publish`. Period. If it doesn't, you get a `NoMethodError` — that's the correct failure mode.

### Never use `method_missing`

If you need dynamic dispatch, use a registry or strategy pattern. `method_missing` hides bugs and makes debugging painful.

### No runtime dependencies in the gemspec

The gem core must be `require`-able with zero gem dependencies beyond stdlib. Platform-specific libraries (`octokit`, `rubyzip`, `nokogiri`, `concurrent-ruby`) are optional. Adapters that need them check at load time:

```ruby
begin
  require "octokit"
rescue LoadError
  raise LoadError, "The octokit gem is required for GitHub adapters. Add `gem 'octokit'` to your Gemfile."
end
```

### All value objects are frozen

After construction, call `freeze`. No setters, no mutation, no `@field =` after `initialize`. Equality is value-based: implement `eql?` and `hash`.

### No conditionals on type

Don't write `if x.is_a?(GitHubPublisher)` or `case platform when :github`. Use the Strategy or Adapter pattern — the caller shouldn't know which concrete type it holds.

## Design Principles

### OOP

Objects own their data and behavior. No anaemic data structures with separate service classes. A `DocumentStage` knows whether it's published. A `NamingStrategy` knows how to compute a tag. A `ChannelManifest` knows how to resolve a policy.

### MECE

Every concern is handled by exactly one class. No two classes do the same thing. Together, all classes cover the entire domain. If you're unsure where a piece of logic belongs, check the responsibility boundary:

| Concern | Owner |
|---------|-------|
| Identifier normalization | `DocumentId` |
| Stage classification | `DocumentStage` |
| Tag format | `ReleaseTag` + `NamingStrategy` |
| Channel matching | `ChannelFilter` |
| Change detection | `ChangeDetector` implementations |
| Zip creation | `ZipPackager` |
| Release publishing | Platform `Publisher` adapters |
| Repo discovery | Platform `Discoverer` adapters |
| Delta state | `DeltaState` |
| Index schema | `DocumentIndex` |
| File organization | `FileRouting` strategies |
| Pipeline orchestration | `ReleasePipeline` / `AggregationPipeline` |
| Argument parsing | `CLI` |
| Task registration | `RakeTasks` |

### Open/Closed

New document types: register a new `NamingStrategy`. New platforms: create a new directory under `platform/`. New file routing modes: create a new `FileRouting` class. New release filters: create a new `Filter` class. **Never modify existing code to add a new variant.**

The registry pattern is the primary mechanism:

```ruby
# Open/Closed: adding a new platform requires zero changes to existing code
class NamingRegistry
  def register(document_type, strategy)    # Add new types here
  def resolve(document_type)               # No case/when — strategy lookup
end
```

### DRY

Don't duplicate the channel model between release and aggregation — both use `Channel`. Don't duplicate content hashing — both pipelines use `ContentHash`. Don't duplicate naming logic — all strategies go through `NamingStrategy`. The `ReleaseMetadata` format is the single data contract between release and aggregate.

### Performance

- Parallel processing where safe: repos in aggregation, documents in release. Use `Thread` with bounded concurrency (no external deps).
- ETag-based skip: don't re-fetch unchanged repo data.
- Content-hash dedup: don't re-extract unchanged release zips.
- Lazy loading: don't `require` platform adapters until needed.
- Frozen strings: add `# frozen_string_literal: true` to every Ruby file.

## Interface Contracts

Ruby doesn't have native interfaces. We use modules with stub methods that raise `NotImplementedError`:

```ruby
module Metanorma::Release::Publisher
  def publish(tag, artifact, metadata, channels:, force_replace: false)
    raise NotImplementedError, "#{self.class} must implement #publish"
  end
end

class GitHubPublisher
  include Metanorma::Release::Publisher

  def publish(tag, artifact, metadata, channels:, force_replace: false)
    # concrete implementation
  end
end
```

This gives us:
- Documentation: the module lists the contract
- Runtime enforcement: missing method → clear error with class name
- Type checking: `publisher.is_a?(Metanorma::Release::Publisher)` if needed

**Never check the interface with `respond_to?`**. If an object includes the module, trust the contract.

## Spec Requirements

### Every value object has exhaustive specs

Test normalization edge cases, equality, hash consistency, rejection of invalid input. Don't just test the happy path — test that `"---"` is rejected by `DocumentId`, that ISO stage 37 falls back to "working-draft", that `Channel.parse("standards")` defaults to public audience.

### Every interface has a shared example

```ruby
RSpec.shared_examples "a naming strategy" do |id:, version:, expected_tag:, expected_asset:, expected_canonical:|
  let(:strategy) { described_class.new }

  it "computes the correct tag" do
    expect(strategy.compute_tag(id, version).to_s).to eq(expected_tag)
  end

  it "computes the correct asset name" do
    expect(strategy.compute_asset_name(id, version)).to eq(expected_asset)
  end

  it "computes the correct canonical base" do
    expect(strategy.compute_canonical_base(id, version)).to eq(expected_canonical)
  end
end
```

### Every pipeline has mock-based specs

Pipelines are tested with mock adapters that implement the interfaces. No real file I/O, no HTTP, no platform APIs in pipeline specs. Use `Struct.new` for quick mocks:

```ruby
let(:mock_publisher) do
  Struct.new(:published) do
    include Metanorma::Release::Publisher

    def published = @published ||= []

    def publish(tag, artifact, metadata, channels:, force_replace: false)
      published << { tag: tag, channels: channels }
      Metanorma::Release::PublishResult.new(tag: tag, url: "mock://#{tag}", created?: true)
    end
  end.new([])
end
```

### Integration specs use local adapters

End-to-end specs exercise the full pipeline with `Local::Publisher`, `Local::DirectoryDiscoverer`, `Local::Fetcher`. No network. Fixtures are committed in `spec/fixtures/`.

### Spec file organization mirrors source

```
lib/metanorma/release/channel.rb       → spec/domain/channel_spec.rb
lib/metanorma/release/release_pipeline.rb → spec/release/release_pipeline_spec.rb
lib/metanorma/release/delta_state.rb    → spec/aggregation/delta_state_spec.rb
lib/metanorma/release/platform/github/publisher.rb → spec/platform/github/publisher_spec.rb
```

## Code Style

- `# frozen_string_literal: true` at the top of every file
- No comments unless the WHY is non-obvious (hidden constraint, workaround, surprising invariant)
- No multi-line docstrings
- `Struct.new(..., keyword_init: true)` for result types and data objects
- Factory methods (`self.from_raw`, `self.from_json`, `self.parse`) for construction with validation
- `include` module interfaces in concrete implementations
- Constructor keyword arguments for DI
- `raise` for programmer errors, return error results for expected failures
- `abort` with message for CLI-level fatal errors

## Key Design Decisions

### `by-document` is the default file routing

Each document gets its own subdirectory. This avoids 500+ files in a flat directory and gives clean URL structure. `flat` mode exists for backward compatibility only.

### `formats` in `index.json` includes all extensions

Including `"rxl"`. The TS aggregate action omits it from `formats` (only in `files`), which forces consumers to merge both arrays. We fix this.

### `doctype` may be empty in `index.json`

It comes from the release metadata, which may not specify it. Consumers derive it from channels if needed. This is a consumer concern, not a gem concern.

### Channel manifest defaults to private

When a `metanorma.release.yml` is loaded but a document is not listed in it, the document is treated as **private** (not released). This is the safe default — you must explicitly declare what gets released.

### Two-phase release pipeline

Phase 1 (change detection) is read-only. Phase 2 (package + publish) is write. This enables dry-run mode and prevents partial state on failure.

### Pipeline errors are collected, not raised

`ReleaseResult.failed` and `AggregationResult.failed_repos` contain errors. The pipeline continues processing. The caller (CLI, Rake) decides whether to abort.

## Porting Notes

The TypeScript implementations (`actions-mn/release` and `actions-mn/aggregate`) are the reference. Port the domain logic faithfully, but apply Ruby idioms:

| TypeScript | Ruby |
|-----------|------|
| `class DocumentId { private constructor(...) }` | `class DocumentId; def self.from_raw(...); end` |
| `interface IChangeDetector { ... }` | `module ChangeDetector; def detect(...) = raise NotImplementedError; end` |
| `readonly` properties | `attr_reader` + `freeze` |
| `enum ChannelAudience` | Module constants + `from_string` method |
| `Record<string, RepoState>` | `Hash` with string keys |
| `readonly Array<T>` | frozen `Array` |
| `Promise<T>` | synchronous Ruby (use `Thread` for parallelism) |
| `minimatch(pattern)` | `File.fnmatch(pattern)` |

Don't port TypeScript type guards (`typeof x === "string"`). Don't port `as` type assertions. Trust the Ruby interface contracts.

## What To Improve Beyond The Plan

As you implement, watch for:

- **Missing value object behavior**: If you're writing the same normalization/comparison logic in multiple places, it belongs in a value object.
- **Leaky abstractions**: If a pipeline starts knowing about GitHub API response formats, the adapter boundary is wrong.
- **Premature concurrency**: Don't add `Thread` until the sequential version is correct and tested. Concurrency is an optimization, not a feature.
- **Over-specification**: Don't test private methods. Test the public interface. Don't test implementation details (method call order, intermediate variables).
- **Schema drift**: If you're adding fields to `AggregatedDocument` or `DocumentIndex`, increment the schema version and add validation.
