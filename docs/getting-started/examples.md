# Examples

Explore real-world examples demonstrating SimpleFlow's capabilities.

## Running Examples

All examples are located in the `examples/` directory of the repository. Run them with:

```bash
ruby examples/example_name.rb
```

## Available Examples

### Parallel Data Fetching

**File:** `examples/parallel_data_fetching.rb`

Demonstrates fetching data from multiple APIs concurrently for improved performance.

**Key Features:**
- Concurrent API calls
- 4x performance improvement (0.4s → 0.1s)
- Result merging and aggregation

**Run:**
```bash
ruby examples/parallel_data_fetching.rb
```

**Learn More:** [Data Fetching Guide](../guides/data-fetching.md)

---

### Parallel Validation

**File:** `examples/parallel_validation.rb`

Shows how to run multiple validation checks concurrently to quickly identify all errors.

**Key Features:**
- Concurrent validation checks
- Error accumulation
- Fast feedback on multiple validation failures

**Run:**
```bash
ruby examples/parallel_validation.rb
```

**Learn More:** [Validation Patterns Guide](../guides/validation-patterns.md)

---

### Error Handling

**File:** `examples/error_handling.rb`

Demonstrates various error handling patterns including validation, graceful degradation, and retry logic.

**Key Features:**
- Validation with error accumulation
- Graceful degradation with optional services
- Retry logic with exponential backoff

**Run:**
```bash
ruby examples/error_handling.rb
```

**Learn More:** [Error Handling Guide](../guides/error-handling.md)

---

### File Processing

**File:** `examples/file_processing.rb`

Shows how to process multiple files in parallel with validation, conversion, and summarization.

**Key Features:**
- Parallel file processing
- Format conversion (JSON to CSV)
- Data validation and summarization

**Run:**
```bash
ruby examples/file_processing.rb
```

**Learn More:** [File Processing Guide](../guides/file-processing.md)

---

### Complex Workflow

**File:** `examples/complex_workflow.rb`

A realistic e-commerce order processing pipeline with multiple stages and parallel execution blocks.

**Key Features:**
- 6-stage workflow
- 4 parallel execution blocks
- 15+ steps
- User validation, inventory checks, payment processing
- Context accumulation across stages

**Run:**
```bash
ruby examples/complex_workflow.rb
```

**Learn More:** [Complex Workflows Guide](../guides/complex-workflows.md)

---

## Code Snippets

### Basic Pipeline

```ruby
require 'simple_flow'

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value.strip) }
  step ->(result) { result.continue(result.value.downcase) }
  step ->(result) { result.continue("Hello, #{result.value}!") }
end

result = pipeline.call(SimpleFlow::Result.new("  WORLD  "))
puts result.value  # => "Hello, world!"
```

### With Middleware

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'abc123'

  step ->(result) { result.continue(result.value + 10) }
  step ->(result) { result.continue(result.value * 2) }
end
```

### Concurrent Execution

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { fetch_user(result) }

  parallel do
    step ->(result) { fetch_orders(result) }
    step ->(result) { fetch_preferences(result) }
    step ->(result) { fetch_analytics(result) }
  end

  step ->(result) { aggregate_data(result) }
end
```

### Error Handling

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    if result.value < 0
      result.halt.with_error(:validation, "Value must be positive")
    else
      result.continue(result.value)
    end
  }

  step ->(result) {
    # Only runs if validation passed
    result.continue(result.value * 2)
  }
end
```

## Performance Benchmarks

Run benchmarks to see SimpleFlow's performance:

```bash
# Compare parallel vs sequential execution
ruby benchmarks/parallel_vs_sequential.rb

# Measure pipeline overhead
ruby benchmarks/pipeline_overhead.rb
```

## Next Steps

- [Core Concepts](../core-concepts/overview.md) - Understand the fundamentals
- [Concurrent Execution](../concurrent/introduction.md) - Deep dive into parallelism
- [API Reference](../api/pipeline.md) - Complete API documentation
