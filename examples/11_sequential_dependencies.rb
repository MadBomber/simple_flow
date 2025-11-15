#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Sequential Step Dependencies Example
#
# This example demonstrates how unnamed steps automatically depend on the
# previous step's success, and how the pipeline short-circuits when a step halts.

puts "=" * 60
puts "Sequential Step Dependencies"
puts "=" * 60
puts

# Example 1: Successful sequential execution
puts "Example 1: All Steps Succeed"
puts "-" * 60
puts

successful_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  [Step 1] Starting workflow..."
    result.continue(result.value + 1)
  }

  step ->(result) {
    puts "  [Step 2] Processing data..."
    result.continue(result.value * 2)
  }

  step ->(result) {
    puts "  [Step 3] Finalizing..."
    result.continue(result.value + 10)
  }
end

result1 = successful_pipeline.call(SimpleFlow::Result.new(5))
puts "\nFinal result: #{result1.value}"
puts "Continue? #{result1.continue?}"
puts "Expected: ((5 + 1) * 2) + 10 = 22"
puts

# Example 2: Pipeline halts in middle step
puts "\nExample 2: Pipeline Halts on Error"
puts "-" * 60
puts

halting_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  [Step 1] Validating input..."
    if result.value.nil?
      return result.halt.with_error(:validation, "Input cannot be nil")
    end
    result.continue(result.value)
  }

  step ->(result) {
    puts "  [Step 2] Checking business rules..."
    if result.value < 0
      return result.halt.with_error(:business_rule, "Value must be positive")
    end
    result.continue(result.value)
  }

  step ->(result) {
    puts "  [Step 3] This step should NOT execute"
    result.continue(result.value * 100)
  }
end

result2 = halting_pipeline.call(SimpleFlow::Result.new(-5))
puts "\nFinal result: #{result2.value}"
puts "Continue? #{result2.continue?}"
puts "Errors: #{result2.errors}"
puts "Note: Step 3 never executed because Step 2 halted"
puts

# Example 3: Early validation pattern
puts "\nExample 3: Early Validation Pattern"
puts "-" * 60
puts

validation_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  [Pre-flight] Checking system health..."
    unless result.context[:system_healthy]
      return result
        .halt("System maintenance in progress")
        .with_error(:system, "Maintenance mode active")
    end
    puts "  [Pre-flight] System healthy, proceeding..."
    result.continue(result.value)
  }

  step ->(result) {
    puts "  [Step 1] Processing order..."
    result.continue(result.value)
  }

  step ->(result) {
    puts "  [Step 2] Charging payment..."
    result.continue(result.value)
  }

  step ->(result) {
    puts "  [Step 3] Sending confirmation..."
    result.continue(result.value)
  }
end

# Test with unhealthy system
puts "Scenario A: System in maintenance mode"
result3a = validation_pipeline.call(
  SimpleFlow::Result.new({ order_id: 123 })
    .with_context(:system_healthy, false)
)
puts "Continue? #{result3a.continue?}"
puts "Errors: #{result3a.errors}"
puts

# Test with healthy system
puts "\nScenario B: System healthy"
result3b = validation_pipeline.call(
  SimpleFlow::Result.new({ order_id: 456 })
    .with_context(:system_healthy, true)
)
puts "Continue? #{result3b.continue?}"
puts "All steps executed successfully!"
puts

# Example 4: Multi-step validation with error accumulation
puts "\nExample 4: Error Accumulation Before Halting"
puts "-" * 60
puts

multi_validation_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  [Step 1] Collecting validation errors..."
    data = result.value
    result_with_errors = result

    # Accumulate all validation errors
    if data[:email].nil? || data[:email].empty?
      result_with_errors = result_with_errors.with_error(:validation, "Email required")
    end

    if data[:name].nil? || data[:name].empty?
      result_with_errors = result_with_errors.with_error(:validation, "Name required")
    end

    if data[:age] && data[:age] < 18
      result_with_errors = result_with_errors.with_error(:validation, "Must be 18+")
    end

    # Halt only if we found errors
    if result_with_errors.errors.any?
      puts "  [Step 1] Found #{result_with_errors.errors[:validation].size} validation error(s)"
      return result_with_errors.halt
    end

    puts "  [Step 1] Validation passed"
    result_with_errors.continue(data)
  }

  step ->(result) {
    puts "  [Step 2] Processing valid data..."
    result.continue("Processed: #{result.value}")
  }
end

invalid_data = { email: "", name: "John", age: 16 }
result4 = multi_validation_pipeline.call(SimpleFlow::Result.new(invalid_data))
puts "\nContinue? #{result4.continue?}"
puts "Errors found: #{result4.errors[:validation].size}"
puts "All errors: #{result4.errors[:validation]}"
puts "Note: Step 2 didn't execute because validation failed"
puts

# Example 5: Comparing sequential vs parallel execution
puts "\nExample 5: Sequential vs Parallel Behavior"
puts "-" * 60
puts

# Sequential pipeline - each step depends on previous
sequential = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  [Sequential 1] Step A"
    result.continue(result.value)
  }

  step ->(result) {
    puts "  [Sequential 2] Step B (depends on A)"
    result.continue(result.value)
  }

  step ->(result) {
    puts "  [Sequential 3] Step C (depends on B)"
    result.continue(result.value)
  }
end

puts "Sequential execution order:"
sequential.call(SimpleFlow::Result.new(nil))

puts "\nParallel execution (for comparison):"

# Parallel pipeline - explicit dependencies
parallel = SimpleFlow::Pipeline.new do
  step :step_a, ->(result) {
    puts "  [Parallel] Step A (no dependencies)"
    result.continue(result.value)
  }, depends_on: []

  step :step_b, ->(result) {
    puts "  [Parallel] Step B (depends on A)"
    result.continue(result.value)
  }, depends_on: [:step_a]

  step :step_c, ->(result) {
    puts "  [Parallel] Step C (depends on A, runs parallel with B)"
    result.continue(result.value)
  }, depends_on: [:step_a]
end

parallel.call_parallel(SimpleFlow::Result.new(nil))

puts "\nNote: Sequential steps have implicit dependencies"
puts "      Parallel steps require explicit depends_on declarations"

puts "\n" + "=" * 60
puts "Sequential dependencies examples completed!"
puts "=" * 60
puts
puts "Key Takeaways:"
puts "  • Unnamed steps execute sequentially in definition order"
puts "  • Each step implicitly depends on the previous step's success"
puts "  • Pipeline halts immediately when any step returns result.halt"
puts "  • Subsequent steps after a halt are never executed"
puts "  • Use named steps with depends_on for parallel execution"
puts
