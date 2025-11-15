# SimpleFlow

A lightweight, modular Ruby framework for building composable data processing pipelines with middleware support and flow control.

## Overview

SimpleFlow provides a clean and flexible architecture for orchestrating multi-step workflows. It emphasizes:

- **Immutability**: Results are immutable, promoting safer concurrent operations
- **Composability**: Steps and middleware can be easily combined and reused
- **Flow Control**: Built-in mechanisms to halt or continue execution based on step outcomes
- **Middleware Support**: Cross-cutting concerns (logging, instrumentation, etc.) via decorator pattern
- **Simplicity**: Minimal API surface with powerful capabilities

## Core Components

### Result (`result.rb:13`)

An immutable value object representing the outcome of a workflow step.

```ruby
result = SimpleFlow::Result.new(initial_value)
  .with_context(:user_id, 123)
  .with_error(:validation, "Invalid input")
```

**Key Methods:**
- `continue(new_value)` - Proceeds to next step with updated value
- `halt(new_value = nil)` - Stops pipeline execution
- `with_context(key, value)` - Adds contextual metadata
- `with_error(key, message)` - Accumulates error messages
- `continue?` - Checks if pipeline should proceed

### Pipeline (`pipeline.rb:19`)

Orchestrates step execution with middleware integration.

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'xyz'

  step ->(result) { result.continue(result.value + 10) }
  step ->(result) { result.continue(result.value * 2) }
end

initial = SimpleFlow::Result.new(5)
final = pipeline.call(initial)  # => Result with value 30
```

**Features:**
- DSL for pipeline configuration
- Automatic middleware application to all steps
- Short-circuit evaluation when `result.continue?` is false
- Steps are any callable object (`#call`)

### Middleware (`middleware.rb`)

Wraps steps with cross-cutting functionality using the decorator pattern.

**Built-in Middleware:**

- **Logging** (`middleware.rb:3`) - Logs before/after step execution
- **Instrumentation** (`middleware.rb:22`) - Measures step duration

**Custom Middleware:**

```ruby
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

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use_middleware AuthMiddleware, required_role: :admin
  step ->(result) { result.continue("Sensitive operation") }
end
```

### StepTracker (`step_tracker.rb:43`)

A `SimpleDelegator` that enriches halted results with context about where execution stopped.

```ruby
tracked_step = SimpleFlow::StepTracker.new(my_step)
result = tracked_step.call(input)
result.context[:halted_step]  # => my_step (if halted)
```

## Usage Examples

### Basic Pipeline

```ruby
require_relative 'simple_flow'

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    result.continue(result.value.strip.downcase)
  }
  step ->(result) {
    result.continue("Hello, #{result.value}!")
  }
end

result = pipeline.call(SimpleFlow::Result.new("  WORLD  "))
puts result.value  # => "Hello, world!"
```

### Error Handling

```ruby
validate_age = ->(result) {
  age = result.value
  if age < 0
    result.halt.with_error(:validation, "Age cannot be negative")
  elsif age < 18
    result.halt.with_error(:validation, "Must be 18 or older")
  else
    result.continue(age)
  end
}

check_eligibility = ->(result) {
  result.continue("Eligible at age #{result.value}")
}

pipeline = SimpleFlow::Pipeline.new do
  step validate_age
  step check_eligibility  # Won't execute if validation fails
end

result = pipeline.call(SimpleFlow::Result.new(15))
puts result.continue?  # => false
puts result.errors     # => {:validation=>["Must be 18 or older"]}
```

### Context Propagation

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    result
      .with_context(:started_at, Time.now)
      .continue(result.value)
  }

  step ->(result) {
    result
      .with_context(:processed_by, "step_2")
      .continue(result.value.upcase)
  }
end

result = pipeline.call(SimpleFlow::Result.new("data"))
puts result.value    # => "DATA"
puts result.context  # => {:started_at=>..., :processed_by=>"step_2"}
```

### Conditional Flow

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    if result.value > 100
      result.halt(result.value).with_error(:limit, "Value exceeds maximum")
    else
      result.continue(result.value)
    end
  }

  step ->(result) {
    result.continue(result.value * 2)  # Only runs if value <= 100
  }
end
```

## Parallel Execution

SimpleFlow supports both automatic parallel step discovery and explicit parallel blocks for concurrent execution.

### Automatic Parallel Discovery

Use named steps with dependencies. SimpleFlow automatically detects which steps can run in parallel:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, ->(result) {
    user = fetch_from_db(:users, result.value)
    result.with_context(:user, user).continue(result.value)
  }, depends_on: []

  # These two steps can run in parallel since they both only depend on :fetch_user
  step :fetch_orders, ->(result) {
    orders = fetch_from_db(:orders, result.context[:user])
    result.with_context(:orders, orders).continue(result.value)
  }, depends_on: [:fetch_user]

  step :fetch_products, ->(result) {
    products = fetch_from_db(:products, result.context[:user])
    result.with_context(:products, products).continue(result.value)
  }, depends_on: [:fetch_user]

  # This step waits for both parallel steps to complete
  step :calculate_total, ->(result) {
    total = calculate(result.context[:orders], result.context[:products])
    result.continue(total)
  }, depends_on: [:fetch_orders, :fetch_products]
end

# Execute with automatic parallelism
result = pipeline.call_parallel(SimpleFlow::Result.new(user_id))
```

**How it works:**
1. SimpleFlow builds a dependency graph from your step declarations
2. Steps with satisfied dependencies run in parallel (e.g., `fetch_orders` and `fetch_products`)
3. Contexts and errors from parallel steps are automatically merged
4. Execution halts if any parallel step calls `halt()`

### Explicit Parallel Blocks

Declare parallel execution explicitly using `parallel` blocks:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    result.continue(validate_input(result.value))
  }

  parallel do
    step ->(result) {
      result.with_context(:api_data, fetch_from_api).continue(result.value)
    }
    step ->(result) {
      result.with_context(:cache_data, fetch_from_cache).continue(result.value)
    }
    step ->(result) {
      result.with_context(:db_data, fetch_from_db).continue(result.value)
    }
  end

  step ->(result) {
    merged = merge_data(
      result.context[:api_data],
      result.context[:cache_data],
      result.context[:db_data]
    )
    result.continue(merged)
  }
end

# Execute normally - parallel blocks are detected automatically
result = pipeline.call(SimpleFlow::Result.new(request))
```

### Async Gem Integration

SimpleFlow uses the `async` gem for parallel execution when available:

```ruby
# Add to Gemfile
gem 'async', '~> 2.0'

# SimpleFlow automatically uses async for parallel execution
pipeline.async_available?  # => true

# Falls back to sequential execution if async is not available
```

**Performance Note:** Parallel execution is most beneficial for I/O-bound operations (API calls, database queries, file operations). For CPU-bound tasks, consider your Ruby implementation's GIL limitations.

### Mixed Sequential and Parallel Steps

You can mix named steps (with automatic parallelism) and unnamed steps (sequential):

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Sequential unnamed step
  step ->(result) { result.continue(sanitize(result.value)) }

  # Named steps with dependencies (automatic parallelism)
  step :step_a, ->(result) { ... }, depends_on: []
  step :step_b, ->(result) { ... }, depends_on: []
  step :step_c, ->(result) { ... }, depends_on: [:step_a, :step_b]

  # Explicit parallel block
  parallel do
    step ->(result) { ... }
    step ->(result) { ... }
  end

  # Another sequential step
  step ->(result) { result.continue(finalize(result.value)) }
end
```

## Dependency Graph Visualization

SimpleFlow includes powerful visualization tools to help you understand and debug your pipelines:

### ASCII Art (Terminal Display)

```ruby
graph = SimpleFlow::DependencyGraph.new(
  fetch_user: [],
  fetch_orders: [:fetch_user],
  fetch_products: [:fetch_user],
  calculate: [:fetch_orders, :fetch_products]
)

visualizer = SimpleFlow::DependencyGraphVisualizer.new(graph)
puts visualizer.to_ascii
```

Output:
```
Dependency Graph
============================================================

Dependencies:
  :fetch_user
    └─ depends on: (none)
  :fetch_orders
    └─ depends on: :fetch_user
  :fetch_products
    └─ depends on: :fetch_user
  :calculate
    └─ depends on: :fetch_orders, :fetch_products

Parallel Execution Groups:
  Group 1:
    └─ :fetch_user (sequential)
  Group 2:
    ├─ Parallel execution of 2 steps:
    ├─ :fetch_orders
    └─ :fetch_products
  Group 3:
    └─ :calculate (sequential)
```

### Execution Plan

```ruby
puts visualizer.to_execution_plan
```

Shows detailed execution strategy with performance estimates:
- Total steps and execution phases
- Which steps run in parallel
- Potential speedup vs sequential execution

### Export Formats

**Graphviz DOT:**
```ruby
File.write('graph.dot', visualizer.to_dot)
# Generate image: dot -Tpng graph.dot -o graph.png
```

**Mermaid Diagram:**
```ruby
File.write('graph.mmd', visualizer.to_mermaid)
# View at https://mermaid.live/
```

**Interactive HTML:**
```ruby
File.write('graph.html', visualizer.to_html(title: "My Pipeline"))
# Open in browser for interactive visualization
```

### Visualize from Pipeline (Recommended)

Pipelines with named steps can be visualized directly without manually creating dependency graphs:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :load, ->(r) { ... }, depends_on: []
  step :process, ->(r) { ... }, depends_on: [:load]
  step :finalize, ->(r) { ... }, depends_on: [:process]
end

# Direct visualization - no manual graph creation needed!
puts pipeline.visualize_ascii
puts pipeline.visualize_ascii(show_groups: false)  # Hide parallel groups

# Export to different formats
File.write('pipeline.dot', pipeline.visualize_dot)
File.write('pipeline.dot', pipeline.visualize_dot(orientation: 'LR'))  # Left-to-right
File.write('pipeline.mmd', pipeline.visualize_mermaid)

# Get execution plan analysis
puts pipeline.execution_plan
```

**Available methods:**
- `pipeline.visualize_ascii(show_groups: true)` - Terminal-friendly ASCII art
- `pipeline.visualize_dot(include_groups: true, orientation: 'TB')` - Graphviz DOT format
- `pipeline.visualize_mermaid()` - Mermaid diagram format
- `pipeline.execution_plan()` - Performance analysis and execution strategy

**Note:** Visualization only works with pipelines that use named steps (with `depends_on`). Returns `nil` for pipelines with only unnamed steps.

See `examples/09_pipeline_visualization.rb` for complete examples.

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
│  │ Steps (executed sequentially)            │  │
│  │  1. Step → Result                        │  │
│  │  2. Step → Result (if continue?)         │  │
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

1. **Pipeline Pattern**: Sequential processing with short-circuit capability
2. **Decorator Pattern**: Middleware wraps steps to add behavior
3. **Immutable Value Object**: Results are never modified, only copied
4. **Builder Pattern**: DSL for pipeline configuration
5. **Chain of Responsibility**: Each step can handle or pass along the result

## Testing

Run the test suite:

```bash
bundle exec rake test
# or
ruby -Ilib:test -e 'Dir["test/*_test.rb"].each { |f| require_relative f }'
```

Test coverage:
- **77 tests, 296 assertions** - All passing
- Pipeline execution and flow control
- Parallel execution (automatic and explicit)
- Middleware integration
- Dependency graph analysis
- Graph visualization (manual and direct from pipeline)
- Error handling and context management

## Dependencies

- Ruby 3.2+ (required)
- Standard library: `delegate`, `logger`, `tsort`
- Optional: `async` (~> 2.0) for parallel execution

## Files

**Core:**
- `simple_flow.rb` - Main module file with overview
- `result.rb` - Immutable result object
- `pipeline.rb` - Pipeline orchestration with parallel support
- `middleware.rb` - Middleware implementations (Logging, Instrumentation)
- `step_tracker.rb` - Step tracking decorator

**Parallel Execution:**
- `dependency_graph.rb` - Dependency graph analysis (adapted from dagwood gem)
- `dependency_graph_visualizer.rb` - Graph visualization (ASCII, DOT, Mermaid, HTML)
- `parallel_executor.rb` - Parallel execution using async gem

**Examples:**
- `examples/` - 9 comprehensive examples demonstrating all features
- `examples/08_graph_visualization.rb` - Manual graph visualization examples
- `examples/09_pipeline_visualization.rb` - Direct pipeline visualization (recommended)

**Tests:**
- `test/*_test.rb` - Comprehensive test suite (77 tests, 296 assertions)

## License

Experimental code - use at your own discretion.
