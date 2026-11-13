## [Unreleased]

### Fixed
- `call_parallel` no longer silently skips steps: named steps inside an unnamed `parallel do` block (and steps that depend on them) now run, and a `depends_on:` naming an unknown step raises `ArgumentError` instead of skipping the step
- Declared `logger` and `tsort` as runtime dependencies so `require "simple_flow"` works under Bundler on Ruby 4.0+ (logger is no longer a default gem as of Ruby 4.0, and tsort as of 4.1)
- `MiddleWare::Logging` now accepts `logger:` as a keyword, so the documented `use_middleware SimpleFlow::MiddleWare::Logging, logger: custom_logger` works instead of raising `NoMethodError` on the first step; the positional `Logging.new(callable, logger)` form still works
- Parallel steps (`call_parallel` and explicit `parallel do` blocks) no longer repeat errors that were already on the incoming result once per branch; each inherited error appears once, followed by the errors each branch added (#18)
- An exception raised by a parallel step under the `async` backend (the default when the gem is installed) now reaches the caller instead of being lost behind `NoMethodError: undefined method 'value' for nil`, and parallel execution works when called inside a reactor that is already running (#30)
- `call_parallel` raises `ArgumentError` naming the steps when `depends_on` forms a cycle or a step depends on itself, instead of silently skipping those steps (#31)
- `DependencyGraphVisualizer#to_html` requires `json` itself, so it no longer raises `NoMethodError` when the `async` gem (which happened to load `json`) is not installed (#33)
- Explicit `parallel do` blocks keep `activated_steps` from the incoming result and from each branch under `call` and `strategy: :explicit` (#34)
- `benchmarks/parallel_vs_sequential.rb` runs on Ruby 4.0 again; it no longer needs `Benchmark.realtime` (#29)

### Documentation
- Corrected README middleware examples to use `use_middleware` (the actual DSL method) instead of the non-existent `use` alias
- Fixed `examples/README.md` async-fallback wording: without the `async` gem, parallel steps fall back to Ruby threads (still parallel), not sequential execution

### Tests
- The `VERSION` test now runs under `rake test`
- The two "async gem not available" tests now run on every build instead of being skipped (#35)
- CI also runs the suite on Ruby 4.0 (#27)
- Regenerated the example regression baselines, which predated 0.4.0, and added one for example 13 (#14)

### Maintenance
- Refreshed development and test dependencies: minitest 6, simplecov 1.x, rubocop 1.92, async 2.46 and others; the runtime dependencies are unchanged (#28)
- Removed unused requires, an unused method argument and unused variables (#32)

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
