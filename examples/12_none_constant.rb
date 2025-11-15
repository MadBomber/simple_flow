#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Using the Pipeline::None Constant for Better Readability
#
# This example demonstrates the use of SimpleFlow::Pipeline::None constant
# for defining steps with no dependencies, providing better readability
# compared to using an empty array.

puts "=" * 60
puts "Pipeline::None Constant Usage"
puts "=" * 60
puts

# Example 1: Using None constant for clarity
puts "Example 1: Using Pipeline::None for Better Readability"
puts "-" * 60
puts

pipeline = SimpleFlow::Pipeline.new do
  # More readable: explicitly shows "no dependencies" using :none
  step :validate, ->(result) {
    puts "  [Step 1] Validating input..."
    result.with_context(:validated, true).continue(result.value)
  }, depends_on: :none  # Much cleaner than []!

  # These two steps run in parallel (both depend only on :validate)
  step :fetch_orders, ->(result) {
    puts "  [Step 2a] Fetching orders in parallel..."
    sleep 0.1
    result.with_context(:orders, [1, 2, 3]).continue(result.value)
  }, depends_on: [:validate]

  step :fetch_products, ->(result) {
    puts "  [Step 2b] Fetching products in parallel..."
    sleep 0.1
    result.with_context(:products, [:a, :b, :c]).continue(result.value)
  }, depends_on: [:validate]

  # This step waits for both parallel steps to complete
  step :merge_data, ->(result) {
    puts "  [Step 3] Merging results..."
    orders = result.context[:orders]
    products = result.context[:products]
    result.continue({
      orders: orders,
      products: products,
      total: orders.size + products.size
    })
  }, depends_on: [:fetch_orders, :fetch_products]
end

result = pipeline.call_parallel(SimpleFlow::Result.new({ user_id: 123 }))
puts "\nResult: #{result.value}"
puts "Context: validated=#{result.context[:validated]}"
puts

# Example 2: Comparison with empty array syntax
puts "\nExample 2: None Constant vs Empty Array"
puts "-" * 60
puts

# Using :none symbol (recommended for readability)
pipeline_with_none = SimpleFlow::Pipeline.new do
  step :root, ->(result) {
    puts "  [:none syntax] Root step with no dependencies"
    result.continue(result.value + 1)
  }, depends_on: :none  # Clean and readable!
end

# Using empty array (functionally equivalent)
pipeline_with_array = SimpleFlow::Pipeline.new do
  step :root, ->(result) {
    puts "  [Array syntax] Root step with no dependencies"
    result.continue(result.value + 1)
  }, depends_on: []  # Works, but less semantic
end

result1 = pipeline_with_none.call_parallel(SimpleFlow::Result.new(5))
result2 = pipeline_with_array.call_parallel(SimpleFlow::Result.new(5))

puts "\nBoth produce the same result: #{result1.value} == #{result2.value}"
puts "The None constant is simply more readable!"
puts

# Example 3: Multiple independent root steps
puts "\nExample 3: Multiple Independent Root Steps"
puts "-" * 60
puts

complex_pipeline = SimpleFlow::Pipeline.new do
  # Three independent root steps - all use :none for clarity
  step :load_config, ->(result) {
    puts "  [Root A] Loading configuration..."
    result.with_context(:config, { timeout: 30 }).continue(result.value)
  }, depends_on: :none

  step :connect_database, ->(result) {
    puts "  [Root B] Connecting to database..."
    result.with_context(:db, :connected).continue(result.value)
  }, depends_on: :none

  step :authenticate_api, ->(result) {
    puts "  [Root C] Authenticating API..."
    result.with_context(:api_token, "abc123").continue(result.value)
  }, depends_on: :none

  # This step depends on all three independent root steps
  step :initialize_app, ->(result) {
    puts "  [Final] Initializing application with all resources..."
    result.continue("Application ready")
  }, depends_on: [:load_config, :connect_database, :authenticate_api]
end

result3 = complex_pipeline.call_parallel(SimpleFlow::Result.new(nil))
puts "\nResult: #{result3.value}"
puts "All independent steps ran in parallel!"
puts

# Example 4: About the :none and :nothing symbols
puts "\nExample 4: Reserved Dependency Symbols"
puts "-" * 60
puts

puts "You can use :none or :nothing to indicate no dependencies:"
puts

pipeline_examples = SimpleFlow::Pipeline.new do
  step :step_a, ->(result) { result.continue(1) }, depends_on: :none
  step :step_b, ->(result) { result.continue(2) }, depends_on: :nothing
  step :step_c, ->(result) { result.continue(3) }, depends_on: [:step_a, :none, :step_b]
end

graph = pipeline_examples.dependency_graph
puts "  • :step_a dependencies: #{graph.dependencies[:step_a].inspect}"
puts "  • :step_b dependencies: #{graph.dependencies[:step_b].inspect}"
puts "  • :step_c dependencies: #{graph.dependencies[:step_c].inspect} (filtered!)"
puts

puts "Reserved symbols :none and :nothing:"
puts "  • Automatically filtered from dependency arrays"
puts "  • Functionally equivalent to []"
puts "  • More semantically clear than empty array"
puts "  • Cannot be used as step names (reserved)"
puts "  • A signal to readers: 'this step has no dependencies'"
puts

puts "=" * 60
puts "Reserved dependency symbols examples completed!"
puts "=" * 60
puts
puts "Key Takeaways:"
puts "  • Use depends_on: :none for better readability"
puts "  • Equivalent to [] but more semantic"
puts "  • Can mix in arrays: [:step_a, :none] becomes [:step_a]"
puts "  • Makes dependency graphs easier to understand"
puts
