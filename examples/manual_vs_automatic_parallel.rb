#!/usr/bin/env ruby
# frozen_string_literal: true

# This example demonstrates BOTH approaches to parallel execution in SimpleFlow:
# 1. Manual parallel blocks (original approach)
# 2. Automatic dependency-based parallelization (new approach with Dagwood)
# 3. Hybrid approach (mixing both in one pipeline)

require_relative '../lib/simple_flow'

puts '=' * 80
puts 'SimpleFlow: Manual vs Automatic Parallel Execution'
puts '=' * 80
puts

# ==============================================================================
# APPROACH 1: MANUAL PARALLEL BLOCKS
# ==============================================================================

puts "APPROACH 1: Manual Parallel Blocks (Original)"
puts '-' * 80
puts "You explicitly declare which steps run in parallel using 'parallel' blocks"
puts

manual_pipeline = SimpleFlow::Pipeline.new do
  # Sequential step
  step ->(result) {
    puts "  [Manual] Fetching user..."
    sleep 0.1
    result.with_context(:user, { id: 123, name: 'Alice' }).continue(result.value)
  }

  # MANUAL parallel block - YOU control parallelization
  parallel do
    step ->(result) {
      puts "  [Manual] Fetching orders (parallel)..."
      sleep 0.1
      result.with_context(:orders, [1, 2, 3]).continue(result.value)
    }

    step ->(result) {
      puts "  [Manual] Fetching preferences (parallel)..."
      sleep 0.1
      result.with_context(:preferences, { theme: 'dark' }).continue(result.value)
    }

    step ->(result) {
      puts "  [Manual] Fetching notifications (parallel)..."
      sleep 0.1
      result.with_context(:notifications, 5).continue(result.value)
    }
  end

  # Sequential step
  step ->(result) {
    puts "  [Manual] Aggregating data..."
    result.continue("Aggregated: user=#{result.context[:user][:name]}, orders=#{result.context[:orders].length}")
  }
end

puts "Executing manual pipeline..."
start = Time.now
manual_result = manual_pipeline.call(SimpleFlow::Result.new({ user_id: 123 }))
manual_time = Time.now - start

puts "\nResult: #{manual_result.value}"
puts "Time: #{(manual_time * 1000).round(2)}ms"
puts

# ==============================================================================
# APPROACH 2: AUTOMATIC DEPENDENCY-BASED PARALLELIZATION
# ==============================================================================

puts "\n" + "APPROACH 2: Automatic Dependency-Based (New with Dagwood)"
puts '-' * 80
puts "You declare named steps with dependencies, and SimpleFlow figures out parallelization"
puts

automatic_pipeline = SimpleFlow::Pipeline.new do
  # Named step with no dependencies
  step :fetch_user, ->(result) {
    puts "  [Auto] Fetching user..."
    sleep 0.1
    result.with_context(:user, { id: 123, name: 'Alice' }).continue(result.value)
  }

  # These steps depend on :fetch_user, so they run AFTER it
  # But they don't depend on EACH OTHER, so they run IN PARALLEL automatically!
  step :fetch_orders, ->(result) {
    puts "  [Auto] Fetching orders (auto-parallel)..."
    sleep 0.1
    result.with_context(:orders, [1, 2, 3]).continue(result.value)
  }, depends_on: [:fetch_user]

  step :fetch_preferences, ->(result) {
    puts "  [Auto] Fetching preferences (auto-parallel)..."
    sleep 0.1
    result.with_context(:preferences, { theme: 'dark' }).continue(result.value)
  }, depends_on: [:fetch_user]

  step :fetch_notifications, ->(result) {
    puts "  [Auto] Fetching notifications (auto-parallel)..."
    sleep 0.1
    result.with_context(:notifications, 5).continue(result.value)
  }, depends_on: [:fetch_user]

  # This depends on the three parallel steps, so it waits for all of them
  step :aggregate, ->(result) {
    puts "  [Auto] Aggregating data..."
    result.continue("Aggregated: user=#{result.context[:user][:name]}, orders=#{result.context[:orders].length}")
  }, depends_on: [:fetch_orders, :fetch_preferences, :fetch_notifications]
end

puts "Executing automatic pipeline..."
start = Time.now
auto_result = automatic_pipeline.call(SimpleFlow::Result.new({ user_id: 123 }))
auto_time = Time.now - start

puts "\nResult: #{auto_result.value}"
puts "Time: #{(auto_time * 1000).round(2)}ms"
puts

# ==============================================================================
# APPROACH 3: CHOOSING YOUR APPROACH
# ==============================================================================

puts "\n" + "APPROACH 3: Choosing Your Approach"
puts '-' * 80
puts "You choose ONE approach per pipeline (manual OR automatic), not both"
puts "But you can use different approaches in different pipelines"
puts

# Simple pipeline with manual parallel blocks
simple_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 1) }

  parallel do
    step ->(result) { result.with_context(:a, true).continue(result.value) }
    step ->(result) { result.with_context(:b, true).continue(result.value) }
  end

  step ->(result) { result.continue(result.value * 2) }
end

# Complex pipeline with automatic dependency-based parallelization
complex_pipeline = SimpleFlow::Pipeline.new do
  step :init, ->(result) { result.continue(result.value + 1) }
  step :task_a, ->(result) { result.with_context(:a, true).continue(result.value) }, depends_on: [:init]
  step :task_b, ->(result) { result.with_context(:b, true).continue(result.value) }, depends_on: [:init]
  step :finalize, ->(result) { result.continue(result.value * 2) }, depends_on: [:task_a, :task_b]
end

puts "Simple pipeline (manual): #{simple_pipeline.call(SimpleFlow::Result.new(5)).value}"
puts "Complex pipeline (automatic): #{complex_pipeline.call(SimpleFlow::Result.new(5)).value}"
puts "Both produce the same result!"
puts

# ==============================================================================
# COMPARISON AND RECOMMENDATIONS
# ==============================================================================

puts "\n" + '=' * 80
puts 'COMPARISON & RECOMMENDATIONS'
puts '=' * 80

puts "\n1. MANUAL PARALLEL BLOCKS"
puts "   ✅ Explicit and obvious"
puts "   ✅ Full control over parallelization"
puts "   ✅ Works with anonymous lambdas"
puts "   ❌ Verbose for complex dependency graphs"
puts "   ❌ No automatic reordering if dependencies change"
puts "   USE WHEN: You have a simple, well-defined parallel section"

puts "\n2. AUTOMATIC DEPENDENCY-BASED"
puts "   ✅ Declares intent (dependencies) not implementation (parallel blocks)"
puts "   ✅ Automatically parallelizes independent steps"
puts "   ✅ Self-documenting (dependencies are visible)"
puts "   ✅ Named steps easier to debug"
puts "   ✅ Can extract subgraphs, reverse order, compose pipelines"
puts "   ❌ Requires named steps"
puts "   ❌ Slightly more verbose for simple cases"
puts "   USE WHEN: You have complex dependencies or want self-documenting code"

puts "\n" + '=' * 80
puts 'KEY INSIGHTS'
puts '=' * 80
puts "1. Both approaches produce the same results and performance!"
puts "2. Choose ONE approach per pipeline (not both in the same pipeline)"
puts "3. Different pipelines in your app can use different approaches"
puts
puts "Decision guide:"
puts "  - Simple, linear pipeline with a few parallel sections?"
puts "    → Use manual parallel blocks"
puts
puts "  - Complex dependencies, pipeline composition, or debugging needs?"
puts "    → Use automatic dependency-based"
puts
puts "  - Not sure? Start with manual, refactor to automatic as it grows complex"
puts '=' * 80
