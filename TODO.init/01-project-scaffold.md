# 01 — Project Scaffold

## Summary

Create the gem skeleton with gemspec, Rakefile, CI workflow, entry point, and directory structure.

## Creates

```
metanorma-release/
├── Gemfile
├── Rakefile
├── metanorma-release.gemspec
├── lib/
│   └── metanorma/
│       └── release.rb              # Entry point: require paths, version constant
├── exe/
│   └── mn-release                  # CLI executable (#!/usr/bin/env ruby)
├── spec/
│   ├── spec_helper.rb
│   └── support/
│       └── factories.rb            # Shared test factories (build(:doc_id), etc.)
├── .github/
│   └── workflows/
│       └── ci.yml
├── .gitignore
├── .rspec
└── CHANGELOG.md
```

## Gemspec dependencies

- **Runtime**: none (pure Ruby core; `json` and `zlib` are stdlib)
- **Dev**: `rspec`, `rake`, `rubocop` (optional)
- **Optional runtime** (not in gemspec, user-installed): `octokit` (GitHub adapter), `relaton-*` (RXL extraction for specific flavors), `rubyzip` (zip packager), `concurrent-ruby` (parallel processing)

Design principle: the gem core has **zero runtime dependencies**. Platform adapters and extractors can declare optional dependencies and fail gracefully at load time.

## Entry point design

```ruby
# lib/metanorma/release.rb
module Metanorma
  module Release
    VERSION = "0.1.0"
  end
end
```

The entry point is minimal — individual files are required explicitly by consumers. This avoids loading platform-specific code (Octokit, etc.) when only the domain model is needed.

Require conventions:
```ruby
require "metanorma/release"                          # Core only
require "metanorma/release/release_pipeline"         # Release pipeline
require "metanorma/release/aggregation_pipeline"     # Aggregation pipeline
require "metanorma/release/platform/github"           # GitHub adapters
require "metanorma/release/platform/local"            # Local adapters
```

## CI workflow

```yaml
# .github/workflows/ci.yml
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby: [3.2, 3.3, 3.4]
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
          bundler-cache: true
      - run: bundle exec rake spec
```

## Spec helper setup

```ruby
# spec/spec_helper.rb
require "metanorma/release"
require_relative "support/factories"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
end
```

## Acceptance

- [ ] `bundle exec rake spec` runs (passes with 0 examples)
- [ ] `bundle exec rake build` produces a `.gem` file
- [ ] `require "metanorma/release"` loads without error
- [ ] CI workflow runs on push
