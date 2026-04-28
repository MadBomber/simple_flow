## [Unreleased]

## [0.4.0] - 2026-04-28

### Added
- `max_concurrent:` keyword on `call_parallel` and `ParallelExecutor.execute_parallel` to cap simultaneous async fibers via `Async::Semaphore`, preventing thundering-herd failures against rate-limited APIs or connection pools
- Thread fallback silently ignores `max_concurrent:` with no error raised

### Fixed
- Explicit `parallel do` blocks now merge contexts and concatenate errors from **all** parallel steps before the next sequential step runs (previously only the last step's result was returned)

### Documentation
- Updated `call_parallel` API docs with `max_concurrent:` parameter and notes on thread fallback
- Updated `parallel` DSL method docs with context-merge and halt short-circuit behaviour
- Updated `ParallelExecutor` API docs with new `max_concurrent:` and `concurrency:` parameters
- Added "Concurrency Capping with `max_concurrent:`" section to parallel-steps guide
- Added back-pressure cap row to concurrency model comparison table
- Updated README with concurrency capping subsection and context-merge note for explicit parallel blocks
- Added `examples/10_concurrency_control.rb` examples for semaphore cap and thread fallback
- Updated `examples/05_parallel_explicit.rb` header to document context-merge and halt behaviour

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
