# Choosing a Concurrency Model

SimpleFlow supports two different approaches for parallel execution: Ruby threads and the async gem (fiber-based). This guide helps you choose the right one for your use case.

## Overview

You can control which concurrency model a pipeline uses in two ways:

### 1. Automatic Detection (Default)

When you create a pipeline without specifying concurrency:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # steps...
end
```

SimpleFlow automatically uses the best available model:
- **Without async gem**: Uses Ruby's built-in threads
- **With async gem**: Uses fiber-based concurrency

### 2. Explicit Concurrency Selection

You can explicitly choose the concurrency model per pipeline:

```ruby
# Force threads (even if async gem is available)
pipeline = SimpleFlow::Pipeline.new(concurrency: :threads) do
  # steps...
end

# Force async (raises error if async gem not available)
pipeline = SimpleFlow::Pipeline.new(concurrency: :async) do
  # steps...
end

# Auto-detect (default behavior)
pipeline = SimpleFlow::Pipeline.new(concurrency: :auto) do
  # steps...
end
```

Both provide **actual parallel execution** - the difference is in how they achieve it and their resource characteristics.

## Ruby Threads (Without async gem)

### How It Works

- Creates actual OS threads (like having multiple workers)
- Each thread runs independently
- Ruby's GIL (Global Interpreter Lock) means only one thread runs Ruby code at a time
- **BUT**: When a thread waits for I/O (network, disk, database), other threads can run

### Best For

- **Simple use cases**: You just want things to run in parallel
- **Blocking I/O operations**:
  - Making HTTP requests to APIs
  - Reading/writing files
  - Database queries
  - Any "waiting" operations
- **Mixed libraries**: Works with any Ruby gem (doesn't need async support)
- **Small-to-medium concurrency**: 10-100 parallel operations

### Resource Usage

- Each thread uses ~1-2 MB of memory
- OS manages thread scheduling
- Limited by system resources (maybe 100-1,000 threads max)

### Example Scenario

```ruby
# Fetching data from 10 different APIs in parallel
pipeline = SimpleFlow::Pipeline.new do
  step :validate, validator, depends_on: []

  # These 10 API calls run in parallel with threads
  step :api_1, ->(r) { r.with_context(:api_1, fetch_api_1) }, depends_on: [:validate]
  step :api_2, ->(r) { r.with_context(:api_2, fetch_api_2) }, depends_on: [:validate]
  # ... 8 more API calls

  step :merge, merger, depends_on: [:api_1, :api_2, ...]
end

# Each API call takes 500ms, threads let them all wait simultaneously
# Total time: ~500ms instead of 5 seconds
result = pipeline.call_parallel(initial_data)
```

---

## Async Gem (Fiber-based)

### How It Works

- Uses Ruby "fibers" (lightweight green threads)
- Cooperative scheduling (fibers yield control when waiting)
- Event loop manages thousands of concurrent operations
- Requires async-aware libraries (async-http, async-postgres, etc.)

### Best For

- **High concurrency**: Thousands of simultaneous operations
- **I/O-heavy applications**: Web scrapers, API gateways, chat servers
- **Long-running services**: Background workers processing many jobs
- **Async-compatible stack**: When using async-aware gems

### Resource Usage

- Each fiber uses ~4-8 KB of memory (250x lighter than threads!)
- Can handle 10,000+ concurrent operations
- More efficient CPU and memory usage

### Example Scenario

```ruby
# Web scraper fetching 10,000 product pages
require 'async'
require 'async/http/internet'

pipeline = SimpleFlow::Pipeline.new do
  step :load_urls, url_loader, depends_on: []

  # With async gem, can handle thousands of concurrent requests
  step :fetch_pages, ->(result) {
    urls = result.value[:urls]
    pages = Async::HTTP::Internet.new.get_all(urls)
    result.with_context(:pages, pages).continue(result.value)
  }, depends_on: [:load_urls]

  step :parse_data, parser, depends_on: [:fetch_pages]
end

# With threads: Would crash or be very slow (10,000 threads = 10+ GB RAM)
# With async: Handles it smoothly (10,000 fibers = ~80 MB RAM)
result = pipeline.call_parallel(initial_data)
```

---

## Decision Guide

### Use Threads (no async gem) when:

✅ You have **10-100 parallel operations**
✅ Using **standard Ruby gems** (not async-compatible)
✅ Making **database queries** or **HTTP requests** with traditional libraries
✅ You want **simple, straightforward code**
✅ Building **internal tools** or **scripts**

**Example:**
```ruby
# E-commerce checkout: Check inventory, calculate shipping, process payment
# 3-5 parallel operations, standard libraries

# Option 1: Auto-detect (uses threads since no async gem needed)
pipeline = SimpleFlow::Pipeline.new do
  step :validate_order, validator, depends_on: []
  step :check_inventory, inventory_checker, depends_on: [:validate_order]
  step :calculate_shipping, shipping_calculator, depends_on: [:validate_order]
  step :process_payment, payment_processor, depends_on: [:check_inventory, :calculate_shipping]
end

# Option 2: Explicitly use threads (works even if async gem is installed)
pipeline = SimpleFlow::Pipeline.new(concurrency: :threads) do
  step :validate_order, validator, depends_on: []
  step :check_inventory, inventory_checker, depends_on: [:validate_order]
  step :calculate_shipping, shipping_calculator, depends_on: [:validate_order]
  step :process_payment, payment_processor, depends_on: [:check_inventory, :calculate_shipping]
end

result = pipeline.call_parallel(order)  # ✅ Threads work great
```

### Use Async (add async gem) when:

✅ You need **1,000+ concurrent operations**
✅ Building **high-performance web services**
✅ Processing **large-scale I/O operations** (web scraping, bulk APIs)
✅ Using **async-compatible libraries** (async-http, async-postgres)
✅ Optimizing **resource usage** (hosting costs, memory limits)

**Example:**
```ruby
# Monitoring service checking 5,000 endpoints every minute
# Need low memory footprint and high concurrency

# Gemfile:
gem 'async', '~> 2.0'
gem 'async-http', '~> 0.60'

# Explicitly require async concurrency for this high-volume pipeline
pipeline = SimpleFlow::Pipeline.new(concurrency: :async) do
  step :load_endpoints, endpoint_loader, depends_on: []

  # Async gem allows 5,000 concurrent health checks efficiently
  step :check_all, health_checker, depends_on: [:load_endpoints]

  step :aggregate_results, aggregator, depends_on: [:check_all]
end

result = pipeline.call_parallel(config)  # ✅ Async is essential
# Raises error if async gem not installed
```

---

## Quick Comparison Table

| Factor | Ruby Threads | Async Gem |
|--------|-------------|-----------|
| **Setup** | None (built-in) | `gem 'async'` |
| **Concurrency Limit** | ~100-1,000 | ~10,000+ |
| **Memory per operation** | 1-2 MB | 4-8 KB |
| **Library compatibility** | Any Ruby gem | Needs async-aware gems |
| **Learning curve** | Simple | Moderate |
| **Speed (I/O)** | Fast | Faster |
| **Speed (CPU)** | GIL-limited | GIL-limited (same) |
| **Best use case** | Standard apps | High-concurrency services |

---

## Real-World Analogy

**Threads** = Hiring separate workers
- Each worker has their own desk, phone, computer (more resources)
- Can have 50-100 workers before office gets crowded
- Workers use regular tools everyone knows
- Easy to manage

**Async** = One worker with a really efficient task list
- Worker rapidly switches between tasks when waiting
- Can juggle 10,000 tasks because they're mostly waiting anyway
- Needs special tools designed for rapid task-switching
- More efficient but requires planning

---

## Switching Between Models

The beauty of SimpleFlow is that you can switch between concurrency models without changing your pipeline code:

### Starting with Threads

```ruby
# Gemfile - no async gem
gem 'simple_flow'

# Your pipeline code
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, user_fetcher, depends_on: []
  step :fetch_orders, order_fetcher, depends_on: [:fetch_user]
  step :fetch_products, product_fetcher, depends_on: [:fetch_user]
end

result = pipeline.call_parallel(data)  # Uses threads
```

### Upgrading to Async

```ruby
# Gemfile - add async gem
gem 'simple_flow'
gem 'async', '~> 2.0'

# Same pipeline code - no changes needed!
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, user_fetcher, depends_on: []
  step :fetch_orders, order_fetcher, depends_on: [:fetch_user]
  step :fetch_products, product_fetcher, depends_on: [:fetch_user]
end

result = pipeline.call_parallel(data)  # Now uses async automatically
```

### Mixing Concurrency Models in One Application

You can use different concurrency models for different pipelines in the same application:

```ruby
# Gemfile - include async for high-volume pipelines
gem 'simple_flow'
gem 'async', '~> 2.0'

# Low-volume pipeline: Use threads for simplicity
user_pipeline = SimpleFlow::Pipeline.new(concurrency: :threads) do
  step :validate, validator, depends_on: []
  step :fetch_profile, profile_fetcher, depends_on: [:validate]
  step :fetch_preferences, prefs_fetcher, depends_on: [:validate]
end

# High-volume pipeline: Use async for efficiency
monitoring_pipeline = SimpleFlow::Pipeline.new(concurrency: :async) do
  step :load_endpoints, endpoint_loader, depends_on: []
  step :check_all, health_checker, depends_on: [:load_endpoints]
  step :alert, alerter, depends_on: [:check_all]
end

# Each pipeline uses its configured concurrency model
user_result = user_pipeline.call_parallel(user_data)        # Uses threads
monitoring_result = monitoring_pipeline.call_parallel(config) # Uses async
```

This allows you to optimize each pipeline based on its specific requirements!

---

## Performance Characteristics

### I/O-Bound Operations

Both threads and async excel at I/O-bound operations (network, disk, database):

```ruby
# API calls, database queries, file operations
# Both models provide significant speedup over sequential execution

# Sequential: 10 API calls × 200ms = 2000ms
# Threads:    10 API calls in parallel = ~200ms
# Async:      10 API calls in parallel = ~200ms

# Winner: Tie (both are fast for moderate I/O)
```

### High Concurrency (1000+ operations)

Async shines when dealing with thousands of concurrent operations:

```ruby
# 5,000 concurrent HTTP requests

# Threads:  5,000 threads × 1.5 MB = 7.5 GB RAM ❌
# Async:    5,000 fibers × 6 KB = 30 MB RAM ✅

# Winner: Async (dramatically lower resource usage)
```

### CPU-Bound Operations

Neither model helps with pure CPU work due to Ruby's GIL:

```ruby
# Heavy computation (image processing, data crunching)
# GIL ensures only one thread/fiber does CPU work at a time

# Sequential: 1000ms
# Threads:    1000ms (GIL limitation)
# Async:      1000ms (GIL limitation)

# Winner: None (use process-based parallelism for CPU work)
```

---

## Common Questions

### Q: Can I use both in the same application?

**A:** Yes! SimpleFlow automatically detects if async is available and uses it. Different pipelines in the same app can use different models.

### Q: Do I need to change my code to switch models?

**A:** No! Just add or remove the `async` gem from your Gemfile. Your pipeline code stays the same.

### Q: What if I'm not sure which to use?

**A:** Start without async (use threads). It's simpler and works great for most use cases. Add async later if you need it.

### Q: Can I check which model is being used?

**A:** Yes! Use the `async_available?` method:

```ruby
pipeline = SimpleFlow::Pipeline.new
puts "Using async: #{pipeline.async_available?}"
```

### Q: Are there any compatibility issues with async?

**A:** Async requires async-aware libraries for best results:
- Use `async-http` instead of `net/http` or `httparty`
- Use `async-postgres` instead of `pg`
- Check if your favorite gems have async versions

With threads, any Ruby gem works out of the box.

---

## Recommendations

### For Most Users

**Start with threads (no async gem):**
- Simpler setup
- Works with any library
- Sufficient for most applications
- Easy to understand and debug

### Upgrade to Async When

You experience any of these:
- ⚠️ High memory usage from threads
- ⚠️ Need more than 100 concurrent operations
- ⚠️ Building high-throughput services
- ⚠️ Already using async-compatible libraries
- ⚠️ Hosting costs driven by memory usage

### Migration Path

1. **Start**: Build with threads (no dependencies)
2. **Measure**: Profile your application under realistic load
3. **Decide**: If you hit thread limits, add async gem
4. **Switch**: Just add gem to Gemfile, no code changes
5. **Optimize**: Gradually adopt async-aware libraries for better performance

---

## Next Steps

- [Parallel Execution](../concurrent/parallel-steps.md) - Deep dive into parallel execution patterns
- [Performance](../concurrent/performance.md) - Benchmarking and optimization tips
- [Best Practices](../concurrent/best-practices.md) - Concurrent programming patterns
- [Error Handling](error-handling.md) - Handling errors in parallel pipelines

---

## Summary

| Your Scenario | Recommendation |
|--------------|----------------|
| Building internal tools, scripts | ✅ **Threads** (no async) |
| Standard web app with DB queries | ✅ **Threads** (no async) |
| Processing 10-100 parallel tasks | ✅ **Threads** (no async) |
| High-volume API gateway | ✅ **Async** (add gem) |
| Web scraper (1000+ requests) | ✅ **Async** (add gem) |
| Real-time chat/notifications | ✅ **Async** (add gem) |
| Background job processor | ✅ **Async** (add gem) |

**Remember:** You can always start simple (threads) and upgrade to async later without changing your pipeline code!
