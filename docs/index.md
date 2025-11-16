# SimpleFlow

<div align="center">

![SimpleFlow Logo](images/logo.svg)

**A lightweight, modular Ruby framework for building composable data processing pipelines with concurrent execution.**

[Get Started](getting-started/quick-start.md){ .md-button .md-button--primary }
[View on GitHub](https://github.com/MadBomber/simple_flow){ .md-button }

</div>

---

## Overview

SimpleFlow provides a clean and flexible architecture for orchestrating multi-step workflows. It emphasizes simplicity, composability, and performance through fiber-based concurrent execution.

## Key Features

### 🔄 Concurrent Execution
Run independent steps in parallel using the Async gem for significant performance improvements.

```ruby
pipeline = SimpleFlow::Pipeline.new do
  parallel do
    step ->(result) { fetch_orders(result) }
    step ->(result) { fetch_preferences(result) }
    step ->(result) { fetch_analytics(result) }
  end
end
```

### 🔗 Composable Pipelines
Build complex workflows from simple, reusable steps with an intuitive DSL.

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { validate(result) }
  step ->(result) { transform(result) }
  step ->(result) { save(result) }
end
```

### 🛡️ Immutable Results
Thread-safe result objects with context and error tracking throughout the pipeline.

```ruby
result = SimpleFlow::Result.new(data)
  .with_context(:user_id, 123)
  .with_error(:validation, "Invalid format")
  .continue(processed_data)
```

### 🔌 Middleware Support
Apply cross-cutting concerns like logging and instrumentation to all steps.

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging
  use_middleware SimpleFlow::MiddleWare::Instrumentation

  step ->(result) { process(result) }
end
```

### ⚡ Flow Control
Halt execution early or continue based on step outcomes with built-in mechanisms.

```ruby
step ->(result) {
  if result.value < 0
    result.halt.with_error(:validation, "Value must be positive")
  else
    result.continue(result.value)
  end
}
```

### 📊 Built for Performance
Fiber-based concurrency without threading overhead, ideal for I/O-bound operations.

**Performance Example:**
- Sequential: ~0.4s (4 × 0.1s operations)
- Parallel: ~0.1s (4 concurrent operations)
- **4x speedup!**

## Quick Example

```ruby
require 'simple_flow'

# Build a user data pipeline
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { validate_user(result) }

  parallel do
    step ->(result) { fetch_profile(result) }
    step ->(result) { fetch_orders(result) }
    step ->(result) { fetch_analytics(result) }
  end

  step ->(result) { aggregate_data(result) }
end

result = pipeline.call(SimpleFlow::Result.new(user_id: 123))
```

## Why SimpleFlow?

- **Simple**: Minimal API surface, maximum power
- **Fast**: Fiber-based concurrency for I/O-bound operations
- **Safe**: Immutable results prevent race conditions
- **Flexible**: Middleware and flow control for any use case
- **Testable**: Easy to unit test individual steps
- **Production-Ready**: Used in real-world applications

## Next Steps

<div class="grid cards" markdown>

-   :material-clock-fast:{ .lg .middle } __Quick Start__

    ---

    Get up and running in 5 minutes

    [:octicons-arrow-right-24: Quick Start](getting-started/quick-start.md)

-   :material-book-open-variant:{ .lg .middle } __Core Concepts__

    ---

    Learn the fundamental concepts

    [:octicons-arrow-right-24: Core Concepts](core-concepts/overview.md)

-   :material-lightning-bolt:{ .lg .middle } __Concurrent Execution__

    ---

    Maximize performance with parallel steps

    [:octicons-arrow-right-24: Concurrency Guide](concurrent/introduction.md)

-   :material-code-braces:{ .lg .middle } __Examples__

    ---

    Real-world examples and patterns

    [:octicons-arrow-right-24: Examples](getting-started/examples.md)

</div>

## Community & Support

- :fontawesome-brands-github: [GitHub Repository](https://github.com/MadBomber/simple_flow)
- :material-bug: [Issue Tracker](https://github.com/MadBomber/simple_flow/issues)
- :material-file-document: [Changelog](https://github.com/MadBomber/simple_flow/blob/main/CHANGELOG.md)

## License

SimpleFlow is released under the [MIT License](https://github.com/MadBomber/simple_flow/blob/main/LICENSE).
