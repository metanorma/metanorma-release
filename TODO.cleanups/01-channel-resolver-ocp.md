# 01 — Extract routing domain model (OCP / model-driven)

## Problem
`Config` mixes data access with routing behavior. Matching logic for pattern,
source, stage, and doctype is embedded as private methods using raw hashes.
This violates OCP — adding a new routing criterion requires modifying Config.

## Solution
Extract value objects that encapsulate matching logic:

- `DocumentEntry` — matches by `pattern` (slug glob) or `source` (file path)
- `RoutingRule` — matches by `stage` and/or `doctype`
- `ChannelResolver` — composes strategies, resolves channels for a Publication

Config becomes a pure data reader. ChannelResolver owns the behavior.
New routing criteria = new value object + register in resolver, no existing code changes.

## Files
- Create `lib/metanorma/release/channel_resolver.rb`
- Update `lib/metanorma/release/config.rb` — remove private routing methods
- Update `lib/metanorma/release/release_pipeline.rb` — use ChannelResolver
- Update `lib/metanorma/release.rb` — add autoload
- Update `spec/domain/config_spec.rb` — move routing specs
- Create `spec/domain/channel_resolver_spec.rb`

## Status
- [x] Implement — DocumentEntry merged with RoutingRule, single `documents` list
- [x] Specs pass — 234 examples, 0 failures
