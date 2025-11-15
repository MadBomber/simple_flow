## [Unreleased]

## [0.1.0] - 2025-11-15

### Added

#### Core Features
- **Immutable Result objects** with value, context, and error tracking
- **Pipeline orchestration** with DSL for building multi-step workflows
- **Middleware support** (Logging, Instrumentation) using decorator pattern
- **Flow control** with `continue` and `halt` mechanisms
- **StepTracker** for debugging halted pipelines

#### Parallel Execution
- **Automatic parallel discovery** using dependency graphs
  - Named steps with `depends_on` parameter
  - Automatic detection of parallelizable steps
  - Topological sorting using Ruby's TSort module
- **Explicit parallel blocks** with `parallel do...end` syntax
- **Async gem integration** for true concurrent execution
  - Automatic fallback to sequential execution if async unavailable
  - Context and error merging from parallel steps
  - Short-circuit on halt in any parallel step

#### Visualization
- **DependencyGraphVisualizer** with multiple output formats:
  - ASCII art for terminal display
  - Graphviz DOT format for diagram generation
  - Mermaid diagram format for documentation
  - Interactive HTML with vis.js library
  - Execution plan analysis with performance estimates
- **Direct pipeline visualization** (no manual graph creation needed):
  - `pipeline.visualize_ascii()`
  - `pipeline.visualize_dot()`
  - `pipeline.visualize_mermaid()`
  - `pipeline.execution_plan()`

#### Development Infrastructure
- **GitHub Actions CI/CD**
  - Multi-version testing (Ruby 2.7, 3.0, 3.1, 3.2, 3.3)
  - Automated RuboCop linting
  - Gem build verification
- **RuboCop configuration** for code quality
- **Benchmark suite** for performance testing
  - Parallel vs sequential execution comparison
  - Pipeline overhead measurement
- **MkDocs documentation** with comprehensive guides

#### Examples
- 9 comprehensive examples demonstrating all features:
  - Basic pipeline usage
  - Error handling and flow control
  - Middleware integration
  - Automatic parallel execution
  - Explicit parallel blocks
  - Real-world e-commerce workflow
  - Real-world ETL pipeline
  - Manual graph visualization
  - Direct pipeline visualization (recommended)

#### Documentation
- Complete README with all features documented
- Architecture diagrams and design patterns
- Getting Started guides
- Core concepts documentation
- API reference

### Fixed
- **Result immutability** - Fixed `halt()` to preserve `@continue` state via `instance_variable_set`
- **Test require paths** - Corrected all test files to use `require_relative '../lib/simple_flow'`
- **Orphaned files** - Removed `pipeline_state_machine.rb` and `result_with_errors.rb`
- **Async result collection** - Fixed parallel execution to properly return results array

### Technical Details
- Dependencies: Ruby 3.2+, async gem (optional for parallel execution)
- Test coverage: 77 tests, 296 assertions, all passing
- Design patterns: Pipeline, Decorator, Immutable Value Object, Builder, Chain of Responsibility
