## [Unreleased]

## [0.3.0] - 2026-01-15

### Added
- Optional steps with dynamic activation via `depends_on: :optional`
- `Result#activate(*step_names)` method for runtime step activation
- `Result#activated_steps` attribute to track activated steps
- `Pipeline#optional_steps` attribute returning Set of optional step names
- Router pattern support for type-based processing paths
- Soft failure pattern for graceful error handling with cleanup
- Chained activation allowing optional steps to activate other optional steps
- Example 13: Optional steps in dynamic DAG demonstration
- Comprehensive optional steps guide in documentation

### Documentation
- Added optional steps section to README.md
- Added optional steps guide (`docs/guides/optional-steps.md`)
- Updated Result API documentation with `activate` method
- Updated Pipeline API documentation with `optional_steps` attribute
- Updated core concepts steps documentation
- Updated examples README with example 13

## [0.2.0] - 2025-12-22

### Breaking Changes
- Middleware API updated to `use_middleware` with `replace: nil` semantics

### Added
- Sequential step dependencies support
- Direct pipeline visualization methods
- Dependency graph visualization with multiple output formats (DOT, PNG, SVG)
- SimpleCov for test coverage
- Rubocop for code style enforcement
- Benchmark-IPS for performance testing
- Timecop dependency for deterministic tests
- GitHub Pages deployment configuration
- Conventional Commits specification

### Changed
- Improved CI workflow configuration
- Enhanced test task

### Documentation
- Added sequential dependencies and execution modes sections to README
- Added example for sequential step dependencies
- Documentation site improvements

## [0.1.0] - 2025-11-15
- First published release of the Ruby gem simple_flow
