#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Controlling Concurrency Model Per Pipeline

puts "=" * 60
puts "Per-Pipeline Concurrency Control"
puts "=" * 60
puts

# Check async availability
async_available = SimpleFlow::ParallelExecutor.async_available?
puts "Async gem available: #{async_available ? '✓ Yes' : '✗ No'}"
puts

# Example 1: Auto-detect (default behavior)
puts "Example 1: Auto-Detect Concurrency (Default)"
puts "-" * 60
puts

pipeline_auto = SimpleFlow::Pipeline.new do  # concurrency: :auto is default
  step ->(result) {
    puts "  Processing with auto-detected concurrency..."
    result.continue(result.value)
  }
end

puts "Pipeline concurrency setting: #{pipeline_auto.concurrency}"
puts "Will use: #{async_available ? 'Async (fiber-based)' : 'Threads'}"
puts

# Example 2: Force threads (even if async is available)
puts "\nExample 2: Force Threads"
puts "-" * 60
puts

pipeline_threads = SimpleFlow::Pipeline.new(concurrency: :threads) do
  parallel do
    step ->(result) {
      puts "  [Thread-based] Task A running..."
      sleep 0.05
      result.with_context(:task_a, :done).continue(result.value)
    }

    step ->(result) {
      puts "  [Thread-based] Task B running..."
      sleep 0.05
      result.with_context(:task_b, :done).continue(result.value)
    }

    step ->(result) {
      puts "  [Thread-based] Task C running..."
      sleep 0.05
      result.with_context(:task_c, :done).continue(result.value)
    }
  end
end

puts "Pipeline concurrency setting: #{pipeline_threads.concurrency}"
puts "Will use: Ruby Threads (even if async is available)"

result = pipeline_threads.call(SimpleFlow::Result.new(nil))
puts "Result context: #{result.context}"
puts

# Example 3: Force async (requires async gem)
puts "\nExample 3: Force Async"
puts "-" * 60
puts

if async_available
  pipeline_async = SimpleFlow::Pipeline.new(concurrency: :async) do
    step :validate, ->(result) {
      puts "  [Async] Validating..."
      result.continue(result.value)
    }, depends_on: []

    step :fetch_a, ->(result) {
      puts "  [Async] Fetching A..."
      sleep 0.05
      result.with_context(:a, :done).continue(result.value)
    }, depends_on: [:validate]

    step :fetch_b, ->(result) {
      puts "  [Async] Fetching B..."
      sleep 0.05
      result.with_context(:b, :done).continue(result.value)
    }, depends_on: [:validate]

    step :merge, ->(result) {
      puts "  [Async] Merging results..."
      result.continue("Complete")
    }, depends_on: [:fetch_a, :fetch_b]
  end

  puts "Pipeline concurrency setting: #{pipeline_async.concurrency}"
  puts "Will use: Async (fiber-based concurrency)"

  result2 = pipeline_async.call_parallel(SimpleFlow::Result.new(nil))
  puts "Result: #{result2.value}"
  puts "Context: #{result2.context}"
else
  puts "Cannot create async pipeline - async gem not available"
  puts "Would raise: ArgumentError: Concurrency set to :async but async gem is not available"
end
puts

# Example 4: Different pipelines, different concurrency
puts "\nExample 4: Mixed Concurrency in Same Application"
puts "-" * 60
puts

# Low-volume user pipeline - threads are simpler
user_pipeline = SimpleFlow::Pipeline.new(concurrency: :threads) do
  step :validate, ->(result) {
    puts "  [User/Threads] Validating user..."
    result.continue(result.value)
  }, depends_on: []

  step :fetch_profile, ->(result) {
    puts "  [User/Threads] Fetching profile..."
    sleep 0.02
    result.with_context(:profile, { name: "John" }).continue(result.value)
  }, depends_on: [:validate]

  step :fetch_settings, ->(result) {
    puts "  [User/Threads] Fetching settings..."
    sleep 0.02
    result.with_context(:settings, { theme: "dark" }).continue(result.value)
  }, depends_on: [:validate]
end

# High-volume batch pipeline - use async if available
batch_concurrency = async_available ? :async : :threads
batch_pipeline = SimpleFlow::Pipeline.new(concurrency: batch_concurrency) do
  step :load, ->(result) {
    puts "  [Batch/#{batch_concurrency.to_s.capitalize}] Loading batch..."
    result.continue(result.value)
  }, depends_on: []

  step :process_batch_1, ->(result) {
    puts "  [Batch/#{batch_concurrency.to_s.capitalize}] Processing batch 1..."
    sleep 0.02
    result.with_context(:batch_1, :done).continue(result.value)
  }, depends_on: [:load]

  step :process_batch_2, ->(result) {
    puts "  [Batch/#{batch_concurrency.to_s.capitalize}] Processing batch 2..."
    sleep 0.02
    result.with_context(:batch_2, :done).continue(result.value)
  }, depends_on: [:load]
end

puts "User pipeline uses: #{user_pipeline.concurrency}"
puts "Batch pipeline uses: #{batch_pipeline.concurrency}"
puts

puts "Running user pipeline..."
user_result = user_pipeline.call_parallel(SimpleFlow::Result.new({ user_id: 123 }))
puts "User result: #{user_result.context}"

puts "\nRunning batch pipeline..."
batch_result = batch_pipeline.call_parallel(SimpleFlow::Result.new({ batch_id: 456 }))
puts "Batch result: #{batch_result.context}"
puts

# Example 5: Error handling for invalid concurrency
puts "\nExample 5: Error Handling"
puts "-" * 60
puts

puts "Valid options: :auto, :threads, :async"
puts

begin
  invalid_pipeline = SimpleFlow::Pipeline.new(concurrency: :invalid) do
    step ->(result) { result.continue(result.value) }
  end
rescue ArgumentError => e
  puts "✓ Caught expected error for invalid concurrency:"
  puts "  #{e.message}"
end

puts

unless async_available
  begin
    async_pipeline = SimpleFlow::Pipeline.new(concurrency: :async) do
      step ->(result) { result.continue(result.value) }
    end
  rescue ArgumentError => e
    puts "✓ Caught expected error when async not available:"
    puts "  #{e.message}"
  end
end

puts

# Example 6: Checking pipeline concurrency setting
puts "\nExample 6: Inspecting Concurrency Settings"
puts "-" * 60
puts

pipelines = [
  SimpleFlow::Pipeline.new,                            # default
  SimpleFlow::Pipeline.new(concurrency: :auto),       # explicit auto
  SimpleFlow::Pipeline.new(concurrency: :threads),    # threads
]

if async_available
  pipelines << SimpleFlow::Pipeline.new(concurrency: :async)  # async
end

pipelines.each_with_index do |pipeline, index|
  puts "Pipeline #{index + 1}:"
  puts "  Concurrency: #{pipeline.concurrency}"
  puts "  Async available: #{pipeline.async_available?}"
  puts
end

puts "=" * 60
puts "Concurrency control examples completed!"
puts "=" * 60
puts
puts "Key Takeaways:"
puts "  • concurrency: :auto (default) - auto-detects best option"
puts "  • concurrency: :threads - always uses Ruby threads"
puts "  • concurrency: :async - requires async gem, uses fibers"
puts "  • Different pipelines can use different concurrency models"
puts "  • Choose based on your specific workload requirements"
puts
