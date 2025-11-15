# Benchmarking Guide

This guide explains how to benchmark SimpleFlow pipelines and measure performance improvements.

## Running Benchmarks

### Basic Benchmark

```ruby
require 'benchmark'
require_relative '../lib/simple_flow'

# Create pipeline
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    sleep 0.1  # Simulate I/O
    result.continue(result.value + 1)
  }

  step ->(result) {
    sleep 0.1  # Simulate I/O
    result.continue(result.value * 2)
  }
end

# Benchmark execution
initial = SimpleFlow::Result.new(5)

time = Benchmark.realtime do
  pipeline.call(initial)
end

puts "Execution time: #{(time * 1000).round(2)}ms"
```

### Parallel vs Sequential Comparison

```ruby
require 'benchmark'
require_relative '../lib/simple_flow'

# Sequential pipeline
sequential = SimpleFlow::Pipeline.new do
  step ->(result) { sleep 0.1; result.continue(result.value) }
  step ->(result) { sleep 0.1; result.continue(result.value) }
  step ->(result) { sleep 0.1; result.continue(result.value) }
  step ->(result) { sleep 0.1; result.continue(result.value) }
end

# Parallel pipeline
parallel = SimpleFlow::Pipeline.new do
  step :step_a, ->(result) {
    sleep 0.1
    result.with_context(:a, true).continue(result.value)
  }, depends_on: []

  step :step_b, ->(result) {
    sleep 0.1
    result.with_context(:b, true).continue(result.value)
  }, depends_on: []

  step :step_c, ->(result) {
    sleep 0.1
    result.with_context(:c, true).continue(result.value)
  }, depends_on: []

  step :step_d, ->(result) {
    sleep 0.1
    result.with_context(:d, true).continue(result.value)
  }, depends_on: []
end

initial = SimpleFlow::Result.new(nil)

puts "Running benchmarks..."
puts "=" * 60

sequential_time = Benchmark.realtime do
  sequential.call(initial)
end

parallel_time = Benchmark.realtime do
  parallel.call_parallel(initial)
end

puts "Sequential: #{(sequential_time * 1000).round(2)}ms"
puts "Parallel:   #{(parallel_time * 1000).round(2)}ms"
puts "Speedup:    #{(sequential_time / parallel_time).round(2)}x"
```

Expected output:
```
Running benchmarks...
============================================================
Sequential: 401.23ms
Parallel:   102.45ms
Speedup:    3.92x
```

## Benchmarking Patterns

### Memory Usage

```ruby
require 'benchmark'
require 'objspace'

def measure_memory
  GC.start
  before = ObjectSpace.memsize_of_all
  yield
  GC.start
  after = ObjectSpace.memsize_of_all
  (after - before) / 1024.0 / 1024.0  # MB
end

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    large_data = Array.new(10000) { |i| { id: i, data: "x" * 100 } }
    result.with_context(:data, large_data).continue(result.value)
  }
end

memory_used = measure_memory do
  pipeline.call(SimpleFlow::Result.new(nil))
end

puts "Memory used: #{memory_used.round(2)} MB"
```

### Throughput Testing

```ruby
require 'benchmark'

def measure_throughput(pipeline, iterations: 1000)
  start = Time.now

  iterations.times do |i|
    pipeline.call(SimpleFlow::Result.new(i))
  end

  duration = Time.now - start
  throughput = iterations / duration

  {
    duration: duration,
    throughput: throughput,
    avg_time: duration / iterations
  }
end

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value * 2) }
  step ->(result) { result.continue(result.value + 10) }
end

stats = measure_throughput(pipeline, iterations: 10000)

puts "Total time: #{stats[:duration].round(2)}s"
puts "Throughput: #{stats[:throughput].round(2)} ops/sec"
puts "Average time per operation: #{(stats[:avg_time] * 1000).round(4)}ms"
```

### Middleware Overhead

```ruby
require 'benchmark'

# Pipeline without middleware
plain_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value * 2) }
end

# Pipeline with middleware
middleware_pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'test'

  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value * 2) }
end

iterations = 1000
initial = SimpleFlow::Result.new(5)

plain_time = Benchmark.realtime do
  iterations.times { plain_pipeline.call(initial) }
end

middleware_time = Benchmark.realtime do
  iterations.times { middleware_pipeline.call(initial) }
end

overhead = ((middleware_time - plain_time) / plain_time * 100)

puts "Plain pipeline: #{(plain_time * 1000).round(2)}ms for #{iterations} iterations"
puts "With middleware: #{(middleware_time * 1000).round(2)}ms for #{iterations} iterations"
puts "Middleware overhead: #{overhead.round(2)}%"
```

## Benchmark Suite

Create a comprehensive benchmark suite:

```ruby
#!/usr/bin/env ruby
# benchmark/suite.rb

require 'benchmark'
require_relative '../lib/simple_flow'

class BenchmarkSuite
  def initialize
    @results = {}
  end

  def run_all
    puts "SimpleFlow Benchmark Suite"
    puts "=" * 60
    puts

    benchmark_sequential_pipeline
    benchmark_parallel_pipeline
    benchmark_middleware_overhead
    benchmark_context_merging
    benchmark_error_handling

    print_summary
  end

  private

  def benchmark_sequential_pipeline
    pipeline = SimpleFlow::Pipeline.new do
      10.times do
        step ->(result) { result.continue(result.value + 1) }
      end
    end

    time = Benchmark.realtime do
      100.times { pipeline.call(SimpleFlow::Result.new(0)) }
    end

    @results[:sequential] = time
    puts "Sequential (10 steps, 100 iterations): #{(time * 1000).round(2)}ms"
  end

  def benchmark_parallel_pipeline
    return unless SimpleFlow::Pipeline.new.async_available?

    pipeline = SimpleFlow::Pipeline.new do
      10.times do |i|
        step "step_#{i}".to_sym, ->(result) {
          result.with_context("step_#{i}".to_sym, true).continue(result.value)
        }, depends_on: []
      end
    end

    time = Benchmark.realtime do
      100.times { pipeline.call_parallel(SimpleFlow::Result.new(0)) }
    end

    @results[:parallel] = time
    puts "Parallel (10 steps, 100 iterations): #{(time * 1000).round(2)}ms"
  end

  def benchmark_middleware_overhead
    pipeline = SimpleFlow::Pipeline.new do
      use_middleware SimpleFlow::MiddleWare::Logging
      step ->(result) { result.continue(result.value) }
    end

    time = Benchmark.realtime do
      100.times { pipeline.call(SimpleFlow::Result.new(0)) }
    end

    @results[:middleware] = time
    puts "Middleware overhead (100 iterations): #{(time * 1000).round(2)}ms"
  end

  def benchmark_context_merging
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) {
        result
          .with_context(:key1, "value1")
          .with_context(:key2, "value2")
          .with_context(:key3, "value3")
          .continue(result.value)
      }
    end

    time = Benchmark.realtime do
      1000.times { pipeline.call(SimpleFlow::Result.new(0)) }
    end

    @results[:context_merging] = time
    puts "Context merging (1000 iterations): #{(time * 1000).round(2)}ms"
  end

  def benchmark_error_handling
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) {
        result
          .with_error(:validation, "Error 1")
          .with_error(:validation, "Error 2")
          .halt
      }
    end

    time = Benchmark.realtime do
      1000.times { pipeline.call(SimpleFlow::Result.new(0)) }
    end

    @results[:error_handling] = time
    puts "Error handling (1000 iterations): #{(time * 1000).round(2)}ms"
  end

  def print_summary
    puts
    puts "=" * 60
    puts "Summary"
    puts "=" * 60

    @results.each do |name, time|
      puts "#{name.to_s.ljust(20)}: #{(time * 1000).round(2)}ms"
    end
  end
end

BenchmarkSuite.new.run_all
```

Run the suite:
```bash
ruby benchmark/suite.rb
```

## Profiling

### Using Ruby's Profiler

```ruby
require 'profile'
require_relative '../lib/simple_flow'

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value * 2) }
end

100.times { pipeline.call(SimpleFlow::Result.new(5)) }
```

### Using ruby-prof

```ruby
require 'ruby-prof'
require_relative '../lib/simple_flow'

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value * 2) }
end

RubyProf.start

1000.times { pipeline.call(SimpleFlow::Result.new(5)) }

result = RubyProf.stop

# Print a flat profile to text
printer = RubyProf::FlatPrinter.new(result)
printer.print($stdout)
```

## Performance Tips

### 1. Minimize Context Size

```ruby
# SLOW: Large context objects
step ->(result) {
  large_data = load_all_users  # 10,000 records
  result.with_context(:users, large_data).continue(result.value)
}

# FAST: Only essential data
step ->(result) {
  users = load_all_users
  user_ids = users.map(&:id)
  result.with_context(:user_ids, user_ids).continue(result.value)
}
```

### 2. Use Parallel Execution for I/O

```ruby
# SLOW: Sequential I/O
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.with_context(:a, fetch_api_a).continue(result.value) }
  step ->(result) { result.with_context(:b, fetch_api_b).continue(result.value) }
  step ->(result) { result.with_context(:c, fetch_api_c).continue(result.value) }
end

# FAST: Parallel I/O
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_a, ->(result) {
    result.with_context(:a, fetch_api_a).continue(result.value)
  }, depends_on: []

  step :fetch_b, ->(result) {
    result.with_context(:b, fetch_api_b).continue(result.value)
  }, depends_on: []

  step :fetch_c, ->(result) {
    result.with_context(:c, fetch_api_c).continue(result.value)
  }, depends_on: []
end
```

### 3. Avoid Unnecessary Steps

```ruby
# SLOW: Too many fine-grained steps
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
end

# FAST: Combine simple operations
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 3) }
end
```

## Related Documentation

- [Testing Guide](testing.md) - Writing tests
- [Performance Guide](../concurrent/performance.md) - Performance characteristics
- [Contributing Guide](contributing.md) - Contributing to SimpleFlow
