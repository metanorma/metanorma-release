# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```
bundle install
bundle exec rspec                    # run all tests
bundle exec rspec spec/domain/       # run tests for a directory
bundle exec rspec spec/domain/channel_spec.rb  # run a single spec file
bundle exec rspec spec/domain/channel_spec.rb:42  # run a single example by line
bundle exec rake                     # runs rspec (default task)
```

The spec directory mirrors the source: `lib/metanorma/release/channel.rb` → `spec/domain/channel_spec.rb`, `lib/metanorma/release/release_pipeline.rb` → `spec/release/release_pipeline_spec.rb`, platform adapters → `spec/platform/`.

## Architecture

This is `metanorma-release`, a Ruby gem (>= 3.2) for managing the release lifecycle of Metanorma documents. It has two main pipelines:

- **ReleasePipeline** (producer): discover compiled docs → extract metadata from RXL → detect changes → package as zip → publish to platform
- **AggregationPipeline** (consumer): discover repos → fetch releases → filter by channel/stage → extract assets → generate `index.json` + file tree

### Dependency flow (unidirectional, no cycles)

```
domain/  →  release/  →  platform/
         →  aggregation/ →  platform/
                          →  cli/
```

- `domain/` (value objects): zero knowledge of pipelines, platforms, or CLI
- Pipelines depend on domain + interfaces, not platform implementations
- Platform adapters (`platform/github/`, `platform/local/`, `platform/null/`) depend on interfaces + domain
- CLI (`cli.rb`) wires pipelines + platform factory together

### Key patterns

- **Value Objects**: Immutable, frozen, value-based equality (`eql?`/`hash`). Factory methods via `self.from_*`.
- **Strategy Pattern**: Pluggable algorithms resolved via registry (naming strategies, file routing modes, platforms).
- **Pipeline with DI**: Pipelines receive all deps through constructor Structs (`Dependencies`, `Config`). No global state.
- **Null Object**: Disabled features inject null implementations (`NullDeltaState`, `NullPublisher`, `NullCacheStore`).
- **Interface modules** (`interfaces.rb`, `aggregation_interfaces.rb`): Ruby modules with `NotImplementedError` stubs. Concrete classes `include` them. Never use `respond_to?` to check.

### Core domain types

`DocumentId`, `DocumentVersion`, `DocumentStage`, `DocumentType`, `Channel`, `ChannelAudience`, `ContentHash`, `ReleaseTag`, `RepoRef`, `ChannelConfig`, `ChannelRegistry`.

### Extending

| To add... | Do this |
|-----------|---------|
| New platform | Create `platform/<name>/` with `Publisher`, `Discoverer`, `Fetcher`, `ManifestReader`; register in `PlatformFactory` |
| New naming strategy | Create class including `NamingStrategy`; register via `NamingRegistry#register` |
| New file routing mode | Create class with `#compute_path(file_name, metadata)`; register in `FileRoutingFactory` |
| New filter | Create class including `Filter`; pass to pipeline's `filters` array |

## Hard Rules

- **Never use `send`, `__send__`, `respond_to?`, or `method_missing`** — use Strategy pattern and interface modules instead
- **No type conditionals** (`if x.is_a?(...)`, `case platform when :github`) — use polymorphism
- **All value objects are frozen** — no mutation after construction; implement `eql?` and `hash`
- **`# frozen_string_literal: true`** at the top of every Ruby file
- **No runtime dependencies** in the gemspec beyond `relaton-bib` — platform-specific gems (`octokit`, etc.) are loaded lazily with `rescue LoadError`
- **Errors collected, not raised** in pipelines — callers inspect `result.failed`
- **No comments** unless the WHY is non-obvious; no multi-line docstrings

## Testing Conventions

- Pipeline specs use mock adapters (Struct-based) implementing interface modules — no real I/O or HTTP
- Integration specs use local adapters with committed fixtures in `spec/fixtures/`
- Shared examples for interface conformance (e.g., `"a naming strategy"`)
- Test factories in `spec/support/factories.rb` (included via RSpec config)
- Test both happy paths and edge cases (invalid input, fallbacks, normalization)
