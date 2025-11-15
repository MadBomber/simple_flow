# Concurrent Execution

One of SimpleFlow's most powerful features is the ability to execute independent steps **concurrently** using fiber-based concurrency.

## Why Concurrent Execution?

Many workflows have steps that don't depend on each other and can run at the same time:

- Fetching data from multiple APIs
- Running independent validation checks
- Processing multiple files
- Enriching data from various sources

Running these steps concurrently can **dramatically improve performance**.

## Performance Benefits

Consider fetching data from 4 APIs:

**Sequential Execution: ~0.4s**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { fetch_api_1(result) }  # 0.1s
  step ->(result) { fetch_api_2(result) }  # 0.1s
  step ->(result) { fetch_api_3(result) }  # 0.1s
  step ->(result) { fetch_api_4(result) }  # 0.1s
end
# Total: 0.4s
```

**Parallel Execution: ~0.1s**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  parallel do
    step ->(result) { fetch_api_1(result) }  # ┐
    step ->(result) { fetch_api_2(result) }  # ├─ All run
    step ->(result) { fetch_api_3(result) }  # ├─ concurrently
    step ->(result) { fetch_api_4(result) }  # ┘
  end
end
# Total: ~0.1s (4x speedup!)
```

## Basic Usage

Use the `parallel` block in your pipeline:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # This runs first (sequential)
  step ->(result) { initialize_data(result) }

  # These run concurrently
  parallel do
    step ->(result) { fetch_orders(result) }
    step ->(result) { fetch_preferences(result) }
    step ->(result) { fetch_analytics(result) }
  end

  # This waits for all parallel steps to complete
  step ->(result) { aggregate_results(result) }
end
```

## How It Works

### Fiber-Based Concurrency

SimpleFlow uses the **Async gem** which provides fiber-based concurrency:

- **No threading overhead**: Fibers are lightweight
- **No GIL limitations**: Not affected by Ruby's Global Interpreter Lock
- **Perfect for I/O**: Ideal for network requests, file operations, etc.

### Result Merging

When parallel steps complete, their results are automatically merged:

```ruby
parallel do
  step ->(result) { result.with_context(:a, 1).continue(result.value) }
  step ->(result) { result.with_context(:b, 2).continue(result.value) }
  step ->(result) { result.with_context(:c, 3).continue(result.value) }
end

# Merged result has all contexts: {:a=>1, :b=>2, :c=>3}
```

**Merging Rules:**
- **Values**: Uses the last non-halted result's value
- **Contexts**: Merges all contexts together
- **Errors**: Merges all errors together
- **Continue**: If any step halts, the merged result is halted

## Real-World Example

### User Data Aggregation

```ruby
require 'simple_flow'
require 'net/http'
require 'json'

pipeline = SimpleFlow::Pipeline.new do
  # Validate user ID
  step ->(result) {
    user_id = result.value
    user_id > 0 ?
      result.continue(user_id) :
      result.halt.with_error(:validation, "Invalid user ID")
  }

  # Fetch data from multiple services concurrently
  parallel do
    step ->(result) {
      user_id = result.value
      profile = fetch_user_profile(user_id)
      result.with_context(:profile, profile).continue(user_id)
    }

    step ->(result) {
      user_id = result.value
      orders = fetch_user_orders(user_id)
      result.with_context(:orders, orders).continue(user_id)
    }

    step ->(result) {
      user_id = result.value
      preferences = fetch_user_preferences(user_id)
      result.with_context(:preferences, preferences).continue(user_id)
    }

    step ->(result) {
      user_id = result.value
      analytics = fetch_user_analytics(user_id)
      result.with_context(:analytics, analytics).continue(user_id)
    }
  end

  # Aggregate all fetched data
  step ->(result) {
    aggregated = {
      user_id: result.value,
      profile: result.context[:profile],
      orders: result.context[:orders],
      preferences: result.context[:preferences],
      analytics: result.context[:analytics]
    }
    result.continue(aggregated)
  }
end

# Execute
result = pipeline.call(SimpleFlow::Result.new(123))
puts result.value[:profile]
# => {...}
```

## Multiple Parallel Blocks

You can have multiple parallel blocks in a pipeline:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { initialize(result) }

  # First parallel block
  parallel do
    step ->(result) { fetch_data_a(result) }
    step ->(result) { fetch_data_b(result) }
  end

  step ->(result) { process_first_batch(result) }

  # Second parallel block
  parallel do
    step ->(result) { enrich_data_a(result) }
    step ->(result) { enrich_data_b(result) }
    step ->(result) { enrich_data_c(result) }
  end

  step ->(result) { finalize(result) }
end
```

## Error Handling

If any parallel step halts, the entire parallel block halts:

```ruby
parallel do
  step ->(result) { result.continue("success") }
  step ->(result) { result.halt.with_error(:service, "Failed") }
  step ->(result) { result.continue("success") }
end
# Result is halted with error: {:service=>["Failed"]}
```

All errors are accumulated:

```ruby
parallel do
  step ->(result) { result.with_error(:a, "Error A").continue(result.value) }
  step ->(result) { result.with_error(:b, "Error B").continue(result.value) }
end
# Result has errors: {:a=>["Error A"], :b=>["Error B"]}
```

## Best Practices

### ✅ Good Use Cases

- **Independent I/O operations**: API calls, database queries
- **Independent validations**: Multiple validation checks
- **Data enrichment**: Fetching supplementary data
- **File processing**: Processing multiple files

### ❌ Poor Use Cases

- **Dependent operations**: When step B needs step A's result
- **CPU-intensive work**: Better with threading or processes
- **Shared mutable state**: Could cause race conditions
- **Very quick operations**: Overhead might outweigh benefits

## When to Use Parallel Execution

Use the `parallel` block when:

1. ✅ Steps are **independent** (don't depend on each other's results)
2. ✅ Steps are **I/O-bound** (network, file, database)
3. ✅ Total execution time of steps > ~50ms
4. ✅ Steps can safely run concurrently

Don't use `parallel` when:

1. ❌ Steps depend on previous results
2. ❌ Steps are very fast (<10ms each)
3. ❌ Steps modify shared state
4. ❌ Steps are CPU-intensive

## Next Steps

- [Parallel Steps Guide](parallel-steps.md) - Deep dive into ParallelStep
- [Performance Tips](performance.md) - Optimize concurrent execution
- [Best Practices](best-practices.md) - Patterns and anti-patterns
- [Examples](../getting-started/examples.md) - See it in action
