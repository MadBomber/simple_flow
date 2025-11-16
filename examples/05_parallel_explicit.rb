#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'
require 'timecop'
Timecop.travel(Time.local(2001, 9, 11, 7, 0, 0))

# Explicit parallel blocks
#
# NOTE: You can control which concurrency model is used with the concurrency parameter:
#   pipeline = SimpleFlow::Pipeline.new(concurrency: :threads) do ... end  # Force threads
#   pipeline = SimpleFlow::Pipeline.new(concurrency: :async) do ... end    # Force async
#   pipeline = SimpleFlow::Pipeline.new(concurrency: :auto) do ... end     # Auto-detect (default)
#
# See examples/10_concurrency_control.rb for detailed examples

puts "=" * 60
puts "Explicit Parallel Blocks"
puts "=" * 60
puts

# Check if async is available
if SimpleFlow::Pipeline.new.async_available?
  puts "✓ Async gem is available - will use fiber-based concurrency"
else
  puts "⚠ Async gem not available - will use thread-based parallelism"
end
puts

# Example 1: Basic parallel block
puts "Example 1: Basic Parallel Block"
puts "-" * 60
puts

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  [Sequential] Pre-processing input..."
    result.continue(result.value)
  }

  parallel do
    step ->(result) {
      puts "  [Parallel A] Fetching from API..."
      sleep 0.1
      result.with_context(:api_data, { status: "ok" }).continue(result.value)
    }

    step ->(result) {
      puts "  [Parallel B] Fetching from cache..."
      sleep 0.1
      result.with_context(:cache_data, { cached: true }).continue(result.value)
    }

    step ->(result) {
      puts "  [Parallel C] Fetching from database..."
      sleep 0.1
      result.with_context(:db_data, { records: 10 }).continue(result.value)
    }
  end

  step ->(result) {
    puts "  [Sequential] Post-processing results..."
    merged = {
      api: result.context[:api_data],
      cache: result.context[:cache_data],
      db: result.context[:db_data]
    }
    result.continue(merged)
  }
end

start_time = Time.now
result = pipeline.call(SimpleFlow::Result.new("data"))
elapsed = Time.now - start_time

puts "\nResult: #{result.value}"
puts "Execution time: #{(elapsed * 1000).round(2)}ms"
puts "(Should be ~100ms with parallel, ~300ms sequential)"
puts

# Example 2: Multiple parallel blocks
puts "\nExample 2: Multiple Parallel Blocks"
puts "-" * 60
puts

multi_parallel_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  [Step 1] Initialize"
    result.continue(result.value)
  }

  parallel do
    step ->(result) {
      puts "  [Block 1.A] Validate email"
      sleep 0.05
      result.with_context(:email_valid, true).continue(result.value)
    }

    step ->(result) {
      puts "  [Block 1.B] Validate phone"
      sleep 0.05
      result.with_context(:phone_valid, true).continue(result.value)
    }
  end

  step ->(result) {
    puts "  [Step 2] Process validations"
    result.continue(result.value)
  }

  parallel do
    step ->(result) {
      puts "  [Block 2.A] Send email notification"
      sleep 0.05
      result.with_context(:email_sent, true).continue(result.value)
    }

    step ->(result) {
      puts "  [Block 2.B] Send SMS notification"
      sleep 0.05
      result.with_context(:sms_sent, true).continue(result.value)
    }

    step ->(result) {
      puts "  [Block 2.C] Log to database"
      sleep 0.05
      result.with_context(:logged, true).continue(result.value)
    }
  end

  step ->(result) {
    puts "  [Step 3] Finalize"
    result.continue("All notifications sent")
  }
end

start_time = Time.now
result2 = multi_parallel_pipeline.call(SimpleFlow::Result.new(nil))
elapsed2 = Time.now - start_time

puts "\nResult: #{result2.value}"
puts "Context: #{result2.context}"
puts "Execution time: #{(elapsed2 * 1000).round(2)}ms"
puts

# Example 3: Mixing named and parallel blocks
puts "\nExample 3: Mixed Execution Styles"
puts "-" * 60
puts

mixed_pipeline = SimpleFlow::Pipeline.new do
  # Traditional unnamed step
  step ->(result) {
    puts "  [Unnamed] Starting workflow..."
    result.continue(result.value)
  }

  # Named steps with dependencies
  step :fetch_config, ->(result) {
    puts "  [Named] Fetching configuration..."
    sleep 0.05
    result.with_context(:config, { timeout: 30 }).continue(result.value)
  }, depends_on: :none

  # Explicit parallel block
  parallel do
    step ->(result) {
      puts "  [Parallel] Processing batch 1..."
      sleep 0.05
      result.with_context(:batch1, :done).continue(result.value)
    }

    step ->(result) {
      puts "  [Parallel] Processing batch 2..."
      sleep 0.05
      result.with_context(:batch2, :done).continue(result.value)
    }
  end

  # Another unnamed step
  step ->(result) {
    puts "  [Unnamed] Finalizing..."
    result.continue("Workflow complete")
  }
end

result3 = mixed_pipeline.call(SimpleFlow::Result.new(nil))
puts "\nResult: #{result3.value}"
puts "Context: #{result3.context}"
puts

# Example 4: Error handling in parallel blocks
puts "\nExample 4: Error Handling in Parallel Blocks"
puts "-" * 60
puts

error_handling_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  [Pre] Starting operations..."
    result.continue(result.value)
  }

  parallel do
    step ->(result) {
      puts "  [Parallel A] Running successfully..."
      sleep 0.05
      result.with_context(:task_a, :success).continue(result.value)
    }

    step ->(result) {
      puts "  [Parallel B] Encountering error..."
      sleep 0.05
      result.halt.with_error(:task_b, "Failed to process batch")
    }

    step ->(result) {
      puts "  [Parallel C] Running successfully..."
      sleep 0.05
      result.with_context(:task_c, :success).continue(result.value)
    }
  end

  step ->(result) {
    puts "  [Post] This should not execute when parallel block halts"
    result.continue("Completed")
  }
end

result4 = error_handling_pipeline.call(SimpleFlow::Result.new(nil))

puts "\nResult:"
puts "  Continue? #{result4.continue?}"
puts "  Value: #{result4.value}"
puts "  Errors: #{result4.errors}"
puts "  Context: #{result4.context}"
puts "  Note: Pipeline halted due to error in parallel block"
puts

# Example 5: Performance comparison
puts "\nExample 5: Performance Comparison"
puts "-" * 60
puts

# Sequential version
sequential_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { sleep 0.1; result.continue(result.value + 1) }
  step ->(result) { sleep 0.1; result.continue(result.value + 1) }
  step ->(result) { sleep 0.1; result.continue(result.value + 1) }
  step ->(result) { sleep 0.1; result.continue(result.value + 1) }
end

# Parallel version
parallel_pipeline = SimpleFlow::Pipeline.new do
  parallel do
    step ->(result) { sleep 0.1; result.continue(result.value + 1) }
    step ->(result) { sleep 0.1; result.continue(result.value + 1) }
    step ->(result) { sleep 0.1; result.continue(result.value + 1) }
    step ->(result) { sleep 0.1; result.continue(result.value + 1) }
  end
end

puts "Running sequential pipeline (4 steps @ 100ms each)..."
sequential_start = Time.now
sequential_result = sequential_pipeline.call(SimpleFlow::Result.new(0))
sequential_time = Time.now - sequential_start

puts "Running parallel pipeline (4 steps @ 100ms each in parallel)..."
parallel_start = Time.now
parallel_result = parallel_pipeline.call(SimpleFlow::Result.new(0))
parallel_time = Time.now - parallel_start

puts "\nResults:"
puts "  Sequential: #{(sequential_time * 1000).round(2)}ms (expected ~400ms)"
puts "  Parallel:   #{(parallel_time * 1000).round(2)}ms (expected ~100ms)"
puts "  Speedup:    #{(sequential_time / parallel_time).round(2)}x"

puts "\n" + "=" * 60
puts "Explicit parallel blocks examples completed!"
puts "=" * 60
