# Performance Characteristics

Understanding the performance implications of parallel execution in SimpleFlow helps you make informed decisions about when and how to use concurrent execution.

## Overview

SimpleFlow uses the `async` gem for true concurrent execution. When the async gem is available, parallel steps run in separate fibers, allowing I/O operations to execute concurrently. When async is not available, SimpleFlow falls back to sequential execution.

## Async Gem Integration

### Checking Availability

```ruby
pipeline = SimpleFlow::Pipeline.new
pipeline.async_available?  # => true if async gem is installed
```

### Installation

Add to your Gemfile:

```ruby
gem 'async', '~> 2.0'
```

Then run:

```bash
bundle install
```

### Fallback Behavior

If async is not available, SimpleFlow automatically falls back to sequential execution:

```ruby
# With async gem
result = pipeline.call_parallel(data)  # Executes in parallel

# Without async gem
result = pipeline.call_parallel(data)  # Executes sequentially (automatically)
```

The API remains identical, ensuring your code works in both scenarios.

## When to Use Parallel Execution

### Ideal Use Cases (I/O-Bound)

Parallel execution provides significant benefits for I/O-bound operations:

#### 1. Multiple API Calls

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_weather, ->(result) {
    # I/O-bound: Network request
    weather = WeatherAPI.fetch(result.value[:location])
    result.with_context(:weather, weather).continue(result.value)
  }, depends_on: []

  step :fetch_news, ->(result) {
    # I/O-bound: Network request
    news = NewsAPI.fetch(result.value[:topic])
    result.with_context(:news, news).continue(result.value)
  }, depends_on: []

  step :fetch_stocks, ->(result) {
    # I/O-bound: Network request
    stocks = StockAPI.fetch(result.value[:symbols])
    result.with_context(:stocks, stocks).continue(result.value)
  }, depends_on: []
end

# Sequential: ~300ms (100ms per API call)
# Parallel: ~100ms (all calls concurrent)
# Speedup: 3x
```

#### 2. Database Queries

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :query_users, ->(result) {
    # I/O-bound: Database query
    users = DB[:users].where(active: true).all
    result.with_context(:users, users).continue(result.value)
  }, depends_on: []

  step :query_posts, ->(result) {
    # I/O-bound: Database query
    posts = DB[:posts].where(published: true).all
    result.with_context(:posts, posts).continue(result.value)
  }, depends_on: []

  step :query_comments, ->(result) {
    # I/O-bound: Database query
    comments = DB[:comments].where(approved: true).all
    result.with_context(:comments, comments).continue(result.value)
  }, depends_on: []
end

# Sequential: ~150ms (50ms per query)
# Parallel: ~50ms (all queries concurrent)
# Speedup: 3x
```

#### 3. File Operations

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :read_config, ->(result) {
    # I/O-bound: File read
    config = JSON.parse(File.read('config.json'))
    result.with_context(:config, config).continue(result.value)
  }, depends_on: []

  step :read_users, ->(result) {
    # I/O-bound: File read
    users = CSV.read('users.csv')
    result.with_context(:users, users).continue(result.value)
  }, depends_on: []

  step :read_logs, ->(result) {
    # I/O-bound: File read
    logs = File.readlines('app.log')
    result.with_context(:logs, logs).continue(result.value)
  }, depends_on: []
end

# Sequential: ~300ms (100ms per file)
# Parallel: ~100ms (all reads concurrent)
# Speedup: 3x
```

### When NOT to Use Parallel Execution

#### 1. CPU-Bound Operations

Due to Ruby's Global Interpreter Lock (GIL), CPU-bound operations do not benefit from parallel execution:

```ruby
# CPU-intensive calculations
pipeline = SimpleFlow::Pipeline.new do
  step :calculate_fibonacci, ->(result) {
    # CPU-bound: No I/O, pure computation
    fib = fibonacci(result.value)
    result.with_context(:fib, fib).continue(result.value)
  }, depends_on: []

  step :calculate_primes, ->(result) {
    # CPU-bound: No I/O, pure computation
    primes = find_primes(result.value)
    result.with_context(:primes, primes).continue(result.value)
  }, depends_on: []
end

# Sequential: ~200ms
# Parallel: ~200ms (no speedup due to GIL)
# Speedup: None
```

**Recommendation**: Use sequential execution for CPU-bound tasks.

#### 2. Steps with Shared State

Avoid parallel execution when steps modify shared state:

```ruby
# BAD: Race conditions
@counter = 0

pipeline = SimpleFlow::Pipeline.new do
  step :increment_a, ->(result) {
    @counter += 1  # Race condition!
    result.continue(result.value)
  }, depends_on: []

  step :increment_b, ->(result) {
    @counter += 1  # Race condition!
    result.continue(result.value)
  }, depends_on: []
end
```

**Recommendation**: Design steps to be independent and use context for data sharing.

#### 3. Small, Fast Operations

Parallel execution has overhead. For very fast operations, the overhead may exceed the benefit:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :upcase_string, ->(result) {
    result.continue(result.value.upcase)  # ~0.001ms
  }, depends_on: []

  step :reverse_string, ->(result) {
    result.continue(result.value.reverse)  # ~0.001ms
  }, depends_on: []
end

# Sequential: ~0.002ms
# Parallel: ~0.5ms (overhead > benefit)
# Slowdown: 250x
```

**Recommendation**: Use parallel execution only when individual steps take at least 10-100ms.

## Performance Benchmarks

### Test Setup

```ruby
require 'benchmark'

# Simulate I/O delay
def simulate_io(duration_ms)
  sleep(duration_ms / 1000.0)
end

# Simple pipeline with 3 parallel steps
pipeline = SimpleFlow::Pipeline.new do
  step :task_a, ->(result) {
    simulate_io(100)
    result.with_context(:a, "done").continue(result.value)
  }, depends_on: []

  step :task_b, ->(result) {
    simulate_io(100)
    result.with_context(:b, "done").continue(result.value)
  }, depends_on: []

  step :task_c, ->(result) {
    simulate_io(100)
    result.with_context(:c, "done").continue(result.value)
  }, depends_on: []
end

initial = SimpleFlow::Result.new(nil)
```

### Results

```ruby
Benchmark.bm do |x|
  x.report("Sequential:") { pipeline.call(initial) }
  x.report("Parallel:  ") { pipeline.call_parallel(initial) }
end
```

Output:
```
                user     system      total        real
Sequential:   0.000000   0.000000   0.000000 (  0.301234)
Parallel:     0.000000   0.000000   0.000000 (  0.101456)
```

**Speedup**: 2.97x (nearly 3x for 3 parallel steps)

### Complex Pipeline

```ruby
# Multi-level pipeline (like e-commerce example)
# Level 1: 1 step (100ms)
# Level 2: 2 parallel steps (100ms each)
# Level 3: 1 step (100ms)
# Level 4: 2 parallel steps (100ms each)

# Sequential: 100 + 100 + 100 + 100 + 100 + 100 = 600ms
# Parallel:   100 + 100 + 100 + 100 = 400ms
# Speedup: 1.5x
```

## GIL Limitations

### Understanding the GIL

Ruby's Global Interpreter Lock (GIL) allows only one thread to execute Ruby code at a time. This means:

1. **I/O Operations**: Can run concurrently (I/O happens outside the GIL)
2. **CPU Operations**: Cannot run concurrently (bound by GIL)

### Example: I/O vs CPU

```ruby
# I/O-bound: Benefits from parallelism
step :fetch_api, ->(result) {
  # Network I/O releases GIL
  response = HTTP.get("https://api.example.com")
  result.with_context(:data, response).continue(result.value)
}

# CPU-bound: No benefit from parallelism
step :calculate, ->(result) {
  # Pure Ruby computation holds GIL
  result = (1..1000000).reduce(:+)
  result.continue(result)
}
```

### Ruby Implementation Differences

Different Ruby implementations handle the GIL differently:

- **MRI (CRuby)**: Has GIL, I/O can be concurrent
- **JRuby**: No GIL, true parallelism for CPU tasks
- **TruffleRuby**: No GIL, true parallelism for CPU tasks

SimpleFlow works with all implementations, but performance characteristics vary.

## Overhead Analysis

### Parallel Execution Overhead

Parallel execution adds overhead from:

1. **Task creation**: Creating async tasks
2. **Synchronization**: Waiting for tasks to complete
3. **Result merging**: Combining contexts and errors

### Overhead Measurements

```ruby
# Overhead for empty steps
pipeline = SimpleFlow::Pipeline.new do
  (1..10).each do |i|
    step "step_#{i}".to_sym, ->(result) {
      result.continue(result.value)
    }, depends_on: []
  end
end

# Sequential: ~0.5ms
# Parallel: ~5ms
# Overhead: ~4.5ms
```

**Guideline**: Parallel execution is worthwhile when:
- Each step takes > 10ms
- Multiple steps can run concurrently
- Steps are I/O-bound

## Optimization Strategies

### 1. Batch Independent Operations

Group independent I/O operations for maximum concurrency:

```ruby
# GOOD: Maximum parallelism
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user_data, ->(result) { ... }, depends_on: []
  step :fetch_product_data, ->(result) { ... }, depends_on: []
  step :fetch_order_data, ->(result) { ... }, depends_on: []
  step :fetch_shipping_data, ->(result) { ... }, depends_on: []
  # All 4 run in parallel
end

# BAD: Artificial dependencies
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user_data, ->(result) { ... }, depends_on: []
  step :fetch_product_data, ->(result) { ... }, depends_on: [:fetch_user_data]
  step :fetch_order_data, ->(result) { ... }, depends_on: [:fetch_product_data]
  # All run sequentially (slower)
end
```

### 2. Minimize Context Size

Large contexts slow down result merging:

```ruby
# GOOD: Only essential data
step :fetch_users, ->(result) {
  users = fetch_all_users
  user_ids = users.map { |u| u[:id] }
  result.with_context(:user_ids, user_ids).continue(result.value)
}

# BAD: Large data structures
step :fetch_users, ->(result) {
  users = fetch_all_users  # Huge array
  result.with_context(:all_users, users).continue(result.value)
}
```

### 3. Use Connection Pools

For database operations, use connection pooling:

```ruby
# Configure connection pool
DB = Sequel.connect(
  'postgres://localhost/mydb',
  max_connections: 10  # Allow concurrent queries
)

pipeline = SimpleFlow::Pipeline.new do
  step :query_a, ->(result) {
    # Uses connection from pool
    data = DB[:table_a].all
    result.with_context(:data_a, data).continue(result.value)
  }, depends_on: []

  step :query_b, ->(result) {
    # Uses different connection from pool
    data = DB[:table_b].all
    result.with_context(:data_b, data).continue(result.value)
  }, depends_on: []
end
```

### 4. Profile Before Optimizing

Measure actual performance before adding parallelism:

```ruby
require 'benchmark'

# Test sequential
sequential_time = Benchmark.realtime do
  pipeline.call(initial_result)
end

# Test parallel
parallel_time = Benchmark.realtime do
  pipeline.call_parallel(initial_result)
end

speedup = sequential_time / parallel_time
puts "Speedup: #{speedup.round(2)}x"
```

## Monitoring and Debugging

### Execution Time Tracking

Add timing to your steps:

```ruby
step :timed_operation, ->(result) {
  start = Time.now

  # Your operation
  data = perform_operation(result.value)

  duration = Time.now - start
  result
    .with_context(:operation_data, data)
    .with_context(:operation_duration, duration)
    .continue(result.value)
}
```

### Visualization

Use visualization tools to understand execution flow:

```ruby
# View execution plan
puts pipeline.execution_plan

# Generate visual diagram
File.write('pipeline.dot', pipeline.visualize_dot)
# Run: dot -Tpng pipeline.dot -o pipeline.png
```

## Performance Testing

See `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/examples/04_parallel_automatic.rb` for performance comparisons showing:

- Parallel vs sequential execution times
- Context merging behavior
- Error handling overhead

## Related Documentation

- [Parallel Steps](parallel-steps.md) - How to use named steps with dependencies
- [Best Practices](best-practices.md) - Recommended patterns for concurrent execution
- [Benchmarking Guide](../development/benchmarking.md) - How to benchmark your pipelines
