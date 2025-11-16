#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'
require 'timecop'
Timecop.travel(Time.local(2001, 9, 11, 7, 0, 0))

# Basic pipeline example demonstrating sequential step execution

puts "=" * 60
puts "Basic Pipeline Example"
puts "=" * 60
puts

# Example 1: Simple data transformation pipeline
puts "Example 1: Data Transformation Pipeline"
puts "-" * 60

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  Step 1: Trimming whitespace"
    result.continue(result.value.strip)
  }

  step ->(result) {
    puts "  Step 2: Converting to uppercase"
    result.continue(result.value.upcase)
  }

  step ->(result) {
    puts "  Step 3: Adding greeting"
    result.continue("Hello, #{result.value}!")
  }
end

initial_result = SimpleFlow::Result.new("  world  ")
final_result = pipeline.call(initial_result)

puts "Input:  '#{initial_result.value}'"
puts "Output: '#{final_result.value}'"
puts

# Example 2: Numerical computation pipeline
puts "\nExample 2: Numerical Computation Pipeline"
puts "-" * 60

computation_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  Step 1: Add 10"
    result.continue(result.value + 10)
  }

  step ->(result) {
    puts "  Step 2: Multiply by 2"
    result.continue(result.value * 2)
  }

  step ->(result) {
    puts "  Step 3: Subtract 5"
    result.continue(result.value - 5)
  }
end

initial_value = SimpleFlow::Result.new(5)
computed_result = computation_pipeline.call(initial_value)

puts "Input:  #{initial_value.value}"
puts "Output: #{computed_result.value}"
puts "Formula: (5 + 10) * 2 - 5 = #{computed_result.value}"
puts

# Example 3: Context propagation
puts "\nExample 3: Context Propagation"
puts "-" * 60

context_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  Step 1: Recording start time"
    result
      .with_context(:started_at, Time.now)
      .continue(result.value)
  }

  step ->(result) {
    puts "  Step 2: Processing data"
    sleep 0.1  # Simulate processing
    result
      .with_context(:processed_at, Time.now)
      .continue(result.value.upcase)
  }

  step ->(result) {
    puts "  Step 3: Recording completion"
    result
      .with_context(:completed_at, Time.now)
      .with_context(:steps_executed, 3)
      .continue(result.value)
  }
end

context_result = context_pipeline.call(SimpleFlow::Result.new("processing"))

puts "Result: #{context_result.value}"
puts "Context:"
context_result.context.each do |key, value|
  puts "  #{key}: #{value}"
end
puts

puts "=" * 60
puts "Basic pipeline examples completed!"
puts "=" * 60
