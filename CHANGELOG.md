## [Unreleased]

### Fixed
- Critical bug in Result class where @continue flag was not preserved when creating new instances
- Fixed test files with incorrect require statements
- Fixed pipeline_test.rb with duplicate Result class definition
- Removed deprecated assertions in tests

### Added
- **Dependency Graph Support** 🔄
  - `DependencyGraph` class for automatic parallelization based on dependencies
  - Named steps with `depends_on` parameter for explicit dependency declaration
  - Automatic topological sorting using Kahn's algorithm (custom implementation)
  - Parallel execution order computation with automatic level detection
  - Pipeline methods: `parallel_order`, `order`, `merge`, `subgraph`
  - Cycle detection with `CyclicDependencyError` to prevent infinite loops
  - Graph composition for building pipelines from reusable components
  - Subgraph extraction for partial pipeline execution
  - Reverse execution order support for cleanup/teardown scenarios
  - Inspired by Dagwood concepts but with custom implementation for SimpleFlow
  - Examples: `manual_vs_automatic_parallel.rb`, `dependency_graph_features.rb`
  - Comprehensive test suite for DependencyGraph (13 tests, 44 assertions)
- **Workflow Visualization** 📈
  - `to_dot` method for DependencyGraph and Pipeline classes
  - Generate Graphviz DOT format for visual pipeline diagrams
  - Options: custom titles, level highlighting with colors, layout direction (TB/LR)
  - Example: `workflow_visualization.rb` with e-commerce, data processing, and ML pipelines
  - 6 new tests for DOT generation (basic, levels, layout, empty graph)
  - Visualize dependencies, parallelization, and execution flow
- **Concurrent Execution Support** 🚀
  - `ParallelStep` class for executing multiple steps concurrently using Async gem
  - `parallel` DSL method in Pipeline for intuitive parallel execution blocks
  - Automatic merging of results, contexts, and errors from parallel steps
  - Fiber-based concurrency for efficient resource usage
  - **Two execution modes**: Manual `parallel` blocks OR automatic dependency-based
- **Development Tools** 🛠️
  - RuboCop for code style enforcement with custom configuration
  - SimpleCov for code coverage tracking (90% line, 80% branch minimum)
  - Benchmark-ips for performance measurement
  - Enhanced Rakefile with coverage and linting tasks
- **Examples Directory** 📚
  - `examples/parallel_data_fetching.rb` - Concurrent API calls (4x speedup)
  - `examples/parallel_validation.rb` - Concurrent validation checks
  - `examples/error_handling.rb` - Error handling patterns and retry logic
  - `examples/file_processing.rb` - Parallel file processing workflows
  - `examples/complex_workflow.rb` - E-commerce order processing pipeline
- **Benchmarks** ⚡
  - `benchmarks/parallel_vs_sequential.rb` - Performance comparisons
  - `benchmarks/pipeline_overhead.rb` - Overhead measurements
- GitHub Actions CI workflow for automated testing across Ruby versions 2.7-3.3
- Comprehensive test suite for all components including concurrent execution
- frozen_string_literal comments to all Ruby files for performance
- Proper gemspec metadata (summary, description, homepage, URLs)
- Better test coverage for StepTracker functionality
- Async gem dependency for fiber-based concurrency
- Development dependencies: rubocop, rubocop-minitest, rubocop-performance, simplecov, benchmark-ips

### Changed
- **Pipeline API Enhancement**: `step` method now accepts Symbol name and `depends_on` for dependency-based execution
- Pipeline now supports **two execution modes**: manual (parallel blocks) OR automatic (dependency-based)
- Updated gemspec required Ruby version to >= 2.7.0 (from >= 3.2.0) for broader compatibility
- Improved file structure and require statements in lib/simple_flow.rb
- Enhanced test reliability and maintainability
- Pipeline now supports both sequential and parallel step execution
- Completely rewritten README with comprehensive dependency graph documentation
- Enhanced CI workflow to include RuboCop linting

## [0.1.0] - 2025-11-13

- Initial release
