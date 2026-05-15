# Changelog

## 0.2.0 (Unreleased)

- Add command classes (`PackageCommand`, `PublishCommand`, `AggregateCommand`) encapsulating pipeline construction
- Add `ConfigResolver` mixin for channel config resolution shared across commands
- Add `Channel.parse_list` for batch channel parsing
- Eliminate DRY violations: CLI delegates to command classes instead of duplicating pipeline wiring
- Eliminate type conditionals: `ChannelRegistry#include?` and `Channel#matches?` use polymorphic dispatch
- Fix `Channel#matches?` to use `Channel.parse` instead of type-conditional string check
- Update dependency flow: CLI -> commands -> pipelines -> domain

## 0.1.0

- Initial release.
