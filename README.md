# SimpleFlow

[![CI](https://github.com/MadBomber/simple_flow/workflows/CI/badge.svg)](https://github.com/MadBomber/simple_flow/actions)
[![Gem Version](https://badge.fury.io/rb/simple_flow.svg)](https://badge.fury.io/rb/simple_flow)

A lightweight, modular Ruby framework for building composable data processing pipelines with middleware support, flow control, and **concurrent execution**.

## Features

- **🔄 Concurrent Execution**: Run independent steps in parallel using the Async gem
  - **Manual mode**: Explicit `parallel` blocks for simple cases
  - **Automatic mode**: Dependency-based execution with automatic parallelization
- **🔗 Composable Pipelines**: Build complex workflows from simple, reusable steps
- **🛡️ Immutable Results**: Thread-safe result objects with context and error tracking
- **🔌 Middleware Support**: Apply cross-cutting concerns like logging and instrumentation
- **⚡ Flow Control**: Halt execution early or continue based on step outcomes
- **📊 Built for Performance**: Fiber-based concurrency without threading overhead
- **🧩 Dependency Graphs**: Topological sorting, cycle detection, subgraph extraction
- **🎯 Simple API**: Minimal surface area, maximum power

## Installation

Add to your Gemfile:

```ruby
gem 'simple_flow'
```

Or install directly:

```bash
gem install simple_flow
```

## Quick Start

```ruby
require 'simple_flow'

# Build a simple pipeline
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value.strip) }
  step ->(result) { result.continue(result.value.downcase) }
  step ->(result) { result.continue("Hello, #{result.value}!") }
end

result = pipeline.call(SimpleFlow::Result.new("  WORLD  "))
puts result.value  # => "Hello, world!"
```

## Core Concepts

### Result

An immutable value object representing the outcome of a pipeline step:

```ruby
result = SimpleFlow::Result.new(42)
  .with_context(:user_id, 123)
  .with_error(:validation, "Invalid input")
  .continue(43)
```

**Methods:**
- `continue(new_value)` - Create new result with updated value (continues flow)
- `halt(new_value = nil)` - Halt pipeline execution
- `with_context(key, value)` - Add contextual metadata
- `with_error(key, message)` - Accumulate error messages
- `continue?` - Check if pipeline should proceed

### Pipeline

Orchestrates step execution with support for middleware and parallel execution:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging

  step ->(result) { validate(result) }
  step ->(result) { process(result) }
  step ->(result) { save(result) }
end
```

## Concurrent Execution 🚀

SimpleFlow supports **two approaches** to parallel execution:

### 1. Manual Parallel Blocks

Explicitly declare which steps run concurrently:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { fetch_user(result) }

  # These run concurrently
  parallel do
    step ->(result) { fetch_orders(result) }
    step ->(result) { fetch_preferences(result) }
    step ->(result) { fetch_analytics(result) }
  end

  step ->(result) { aggregate_data(result) }
end
```

**Best for**: Simple pipelines with obvious parallel sections

### 2. Automatic Dependency-Based Execution

Declare named steps with dependencies, and SimpleFlow automatically parallelizes:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, ->(result) { fetch_user(result) }

  # These automatically run in parallel (no dependency between them)
  step :fetch_orders, ->(result) { fetch_orders(result) }, depends_on: [:fetch_user]
  step :fetch_preferences, ->(result) { fetch_prefs(result) }, depends_on: [:fetch_user]
  step :fetch_analytics, ->(result) { fetch_analytics(result) }, depends_on: [:fetch_user]

  # This waits for all three to complete
  step :aggregate, ->(result) { aggregate_data(result) },
    depends_on: [:fetch_orders, :fetch_preferences, :fetch_analytics]
end

# See the computed execution order
puts pipeline.parallel_order.inspect
# => [[:fetch_user], [:fetch_orders, :fetch_preferences, :fetch_analytics], [:aggregate]]
```

**Best for**: Complex dependency graphs, pipeline composition, debugging

**Benefits of dependency-based execution:**
- 🎯 Self-documenting (dependencies are explicit)
- 🔍 Better debugging (named steps)
- 🧩 Composable (merge pipelines, extract subgraphs)
- ♻️ Reverse execution order for cleanup/teardown
- 🔄 Automatic cycle detection

See `examples/manual_vs_automatic_parallel.rb` and `examples/dependency_graph_features.rb` for detailed comparisons.

### Performance Benefits

```ruby
# Sequential: ~0.4s (4 × 0.1s operations)
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { slow_api_call_1(result) }  # 0.1s
  step ->(result) { slow_api_call_2(result) }  # 0.1s
  step ->(result) { slow_api_call_3(result) }  # 0.1s
  step ->(result) { slow_api_call_4(result) }  # 0.1s
end

# Parallel: ~0.1s (4 concurrent operations)
pipeline = SimpleFlow::Pipeline.new do
  parallel do
    step ->(result) { slow_api_call_1(result) }  # ┐
    step ->(result) { slow_api_call_2(result) }  # ├─ All run
    step ->(result) { slow_api_call_3(result) }  # ├─ concurrently
    step ->(result) { slow_api_call_4(result) }  # ┘
  end
end
```

## Middleware

Apply cross-cutting concerns to all steps:

```ruby
# Built-in middleware
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'xyz'

  step ->(result) { process(result) }
end

# Custom middleware
class AuthMiddleware
  def initialize(callable, required_role:)
    @callable = callable
    @required_role = required_role
  end

  def call(result)
    return result.halt.with_error(:auth, "Unauthorized") unless authorized?(result)
    @callable.call(result)
  end

  private

  def authorized?(result)
    result.context[:user_role] == @required_role
  end
end

pipeline = SimpleFlow::Pipeline.new do
  use_middleware AuthMiddleware, required_role: :admin
  step ->(result) { sensitive_operation(result) }
end
```

## Error Handling

### Accumulate Errors

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    age = result.value
    if age < 0
      result.halt.with_error(:validation, "Age cannot be negative")
    elsif age < 18
      result.halt.with_error(:validation, "Must be 18 or older")
    else
      result.continue(age)
    end
  }
end

result = pipeline.call(SimpleFlow::Result.new(15))
puts result.errors  # => {:validation=>["Must be 18 or older"]}
```

### Parallel Validation

```ruby
pipeline = SimpleFlow::Pipeline.new do
  parallel do
    step ->(result) { validate_email(result) }
    step ->(result) { validate_password(result) }
    step ->(result) { validate_age(result) }
  end

  step ->(result) {
    result.errors.any? ? result.halt : result.continue(result.value)
  }
end
```

## Examples

The `examples/` directory contains real-world use cases:

### Manual vs Automatic Parallel Execution

Compare both approaches side-by-side:

```bash
ruby examples/manual_vs_automatic_parallel.rb
```

Shows when to use manual `parallel` blocks vs automatic dependency-based execution.

### Dependency Graph Features

Explore advanced DependencyGraph capabilities:

```bash
ruby examples/dependency_graph_features.rb
```

Demonstrates subgraph extraction, graph merging, reverse order, and cycle detection.

### Parallel Data Fetching

Fetch from multiple APIs concurrently:

```bash
ruby examples/parallel_data_fetching.rb
```

Demonstrates 4x speedup (0.4s → 0.1s) for independent API calls.

### Parallel Validation

Run multiple validation checks concurrently:

```bash
ruby examples/parallel_validation.rb
```

### Error Handling

Graceful degradation and retry logic:

```bash
ruby examples/error_handling.rb
```

### File Processing

Process multiple files in parallel:

```bash
ruby examples/file_processing.rb
```

### Complex Workflow

E-commerce order processing with multiple parallel stages:

```bash
ruby examples/complex_workflow.rb
```

## Benchmarks

Run performance benchmarks:

```bash
# Compare parallel vs sequential execution
ruby benchmarks/parallel_vs_sequential.rb

# Measure pipeline overhead
ruby benchmarks/pipeline_overhead.rb
```

## Testing

```bash
# Run tests
rake test

# Run tests with coverage
rake coverage

# Run RuboCop
rake rubocop

# Run all checks
rake
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   Pipeline                      │
│  ┌───────────────────────────────────────────┐  │
│  │ Middleware Stack (applied in reverse)    │  │
│  │  - Instrumentation                       │  │
│  │  - Logging                               │  │
│  │  - Custom...                             │  │
│  └───────────────────────────────────────────┘  │
│                      ↓                          │
│  ┌───────────────────────────────────────────┐  │
│  │ Sequential Steps                         │  │
│  │  1. Step → Result                        │  │
│  │  2. Parallel Block → Merged Result       │  │
│  │     ├─ Step A ┐                          │  │
│  │     ├─ Step B ├─ (concurrent)            │  │
│  │     └─ Step C ┘                          │  │
│  │  3. Step → Result (if continue?)         │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                       ↓
              ┌────────────────┐
              │ Final Result   │
              │  - value       │
              │  - context     │
              │  - errors      │
              └────────────────┘
```

## Design Patterns

- **Pipeline Pattern**: Sequential processing with short-circuit capability
- **Decorator Pattern**: Middleware wraps steps to add behavior
- **Immutable Value Object**: Results are never modified, only copied
- **Builder Pattern**: DSL for pipeline configuration
- **Chain of Responsibility**: Each step can handle or pass along the result

## Requirements

- Ruby >= 2.7.0
- async ~> 2.0 (for concurrent execution)
- dagwood ~> 1.0 (for dependency graph management)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details

## Credits

Created by [Dewayne VanHoozer](https://github.com/MadBomber)
