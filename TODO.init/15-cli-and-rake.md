# 15 — CLI & Rake Integration

## Summary

Implement the `mn-release` CLI (`package`, `publish`, `aggregate` commands) and `RakeTasks` integration. The CLI is a thin wrapper over the library — it parses arguments, constructs pipeline dependencies, runs the pipeline, and reports results.

## Dependencies

- 01 through 14 (all previous tasks)

## Creates

```
lib/metanorma/release/
├── cli.rb                      # CLI entry point + option parsing
└── rake_tasks.rb               # Rake task definitions

exe/
└── mn-release                  # CLI executable

spec/
├── cli_spec.rb
└── rake_tasks_spec.rb
```

## Design Principles

### CLI is a thin layer
No business logic in the CLI. It constructs the right pipeline with the right adapters and runs it. Error messages map pipeline results to human-readable output.

### Rake tasks mirror CLI commands
Each CLI command has a corresponding rake task. Users who prefer Rake can use it instead of the CLI. Same behavior, different interface.

### No framework dependency
CLI uses Ruby's stdlib `OptionParser`. No Thor, no dry-cli, no external CLI framework. Keeps the gem dependency-free for core usage.

### Exit codes
- 0: success
- 1: pipeline error (some documents/repos failed)
- 2: configuration error (invalid arguments)
- 0 with warnings: pipeline succeeded but with skipped items

---

## CLI Commands

### `mn-release package`

Package compiled documents for local distribution.

```bash
mn-release package [options]
  --output-dir DIR       # Directory containing compiled docs (default: _site)
  --dest DIR             # Destination for packages (default: dist)
  --manifest FILE        # Release manifest file (default: metanorma.release.yml)
  --canonicalize         # Strip edition suffixes (default: true)
  --concurrency N        # Parallel processing (default: 4)
```

Constructs: `ReleasePipeline` with `ZipPackager` + `NullPublisher` (package only, no publishing).

Output:
```
Packaged 3 documents → dist/
  cc-18011-ed1.zip
  cc-19060-ed1.zip
  cc-51015-ed1.zip
```

### `mn-release publish`

Package and publish documents to a platform.

```bash
mn-release publish [options]
  --platform NAME        # github | gitlab | local (default: github)
  --output-dir DIR       # Compiled docs directory (default: _site)
  --manifest FILE        # Release manifest (default: metanorma.release.yml)
  --force                # Force release even if unchanged
  --force-replace PAT    # Glob patterns for force-replace
  --channels CHANS       # Override channels (comma-separated)
  --concurrency N        # Parallel processing (default: 4)
  --token TOKEN          # Platform authentication token
```

Constructs: `ReleasePipeline` with platform-specific `Publisher`.

Output:
```
Released 2, skipped 1, failed 0
  RELEASED: cc-18011 (ed1)
  RELEASED: cc-19060 (ed1)
  SKIPPED: cc-51015 (unchanged)
```

### `mn-release aggregate`

Aggregate released documents into index + file tree.

```bash
mn-release aggregate [options]
  --source SOURCE        # github | local:PATH (default: github)
  --organizations ORGS   # GitHub organizations (comma-separated)
  --topic TOPIC          # Repository topic (default: metanorma-release)
  --repos REPOS          # Explicit repo list (comma-separated, skips discovery)
  --channels CHANS       # Filter channels (comma-separated, empty = all)
  --stages STAGES        # Filter stages (comma-separated, empty = all)
  --output-dir DIR       # Output directory (default: _site/cc)
  --file-routing MODE    # by-document | flat | by-format (default: by-document)
  --canonicalize         # Strip edition suffixes (default: true)
  --cache-dir DIR        # Cache directory for ETags/delta state
  --include-drafts       # Include draft releases
  --concurrency N        # Parallel repo processing (default: 4)
  --min-documents N      # Fail if fewer documents found (default: 0)
  --token TOKEN          # Platform authentication token
```

Constructs: `AggregationPipeline` with platform-specific adapters.

Output:
```
Aggregated 189 documents from 51 repos
Index: _site/cc/index.json
Channels: public/standards, public/reports, public/advisories
```

---

## CLI Implementation

```ruby
module Metanorma::Release::CLI
  def self.run(argv)
    command = argv.shift
    case command
    when "package"  then run_package(argv)
    when "publish"  then run_publish(argv)
    when "aggregate" then run_aggregate(argv)
    when nil        then abort("Usage: mn-release <package|publish|aggregate> [options]")
    else abort("Unknown command: #{command}")
    end
  end

  private

  def self.run_package(argv)
    options = parse_package_options(argv)
    # Construct pipeline with NullPublisher
    # Run pipeline
    # Print results
  end

  def self.run_publish(argv)
    options = parse_publish_options(argv)
    # Construct pipeline with platform publisher
    # Run pipeline
    # Print results
    # Exit 1 if any failures
  end

  def self.run_aggregate(argv)
    options = parse_aggregate_options(argv)
    # Construct aggregation pipeline with platform adapters
    # Run pipeline
    # Write index
    # Print results
    # Exit 1 if min_documents not met
  end
end
```

---

## Rake Tasks

```ruby
# In user's Rakefile:
require "metanorma/release/rake_tasks"

Metanorma::Release::RakeTasks.install do |t|
  t.output_dir = "_site"
  t.manifest = "metanorma.release.yml"
  t.platform = "github"
  t.concurrency = 4
end

# Provides:
#   rake mn:package
#   rake mn:publish
#   rake mn:aggregate
```

```ruby
class Metanorma::Release::RakeTasks
  include Rake::DSL

  def self.install(&block)
    new(&block).install
  end

  def initialize(&block)
    @config = OpenStruct.new(
      output_dir: "_site",
      manifest: "metanorma.release.yml",
      platform: "github",
      concurrency: 4
    )
    block.call(@config) if block
  end

  def install
    desc "Package compiled documents"
    task :"mn:package" do
      # Delegate to CLI.run_package with config
    end

    desc "Package and publish documents"
    task :"mn:publish" do
      # Delegate to CLI.run_publish with config
    end

    desc "Aggregate released documents"
    task :"mn:aggregate" do
      # Delegate to CLI.run_aggregate with config
    end
  end
end
```

---

## Specs

### CLI specs
- `mn-release package` creates packages in dest directory
- `mn-release publish --platform github` calls GitHub publisher
- `mn-release publish --platform local` writes to filesystem
- `mn-release aggregate --source github` fetches from GitHub
- `mn-release aggregate --source local:/path` reads from directory
- `mn-release` without command shows usage
- `mn-release unknown` shows error
- Exit code 0 on success
- Exit code 1 on pipeline failure
- Exit code 2 on invalid options
- `--min-documents 5` fails if fewer found

### Rake task specs
- `rake mn:package` delegates to package command
- `rake mn:publish` delegates to publish command
- `rake mn:aggregate` delegates to aggregate command
- Config block sets defaults

---

## Acceptance

- [ ] CLI `mn-release package/publish/aggregate` work end-to-end
- [ ] Rake tasks `mn:package/publish/aggregate` work end-to-end
- [ ] Exit codes: 0 success, 1 failure, 2 config error
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
