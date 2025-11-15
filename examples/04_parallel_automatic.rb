#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Automatic parallel discovery using dependency graphs

puts "=" * 60
puts "Automatic Parallel Discovery"
puts "=" * 60
puts

# Check if async is available
if SimpleFlow::Pipeline.new.async_available?
  puts "✓ Async gem is available - true parallel execution enabled"
else
  puts "⚠ Async gem not available - falling back to sequential execution"
end
puts

# Example 1: Basic parallel discovery
puts "Example 1: Basic Parallel Execution"
puts "-" * 60
puts

pipeline = SimpleFlow::Pipeline.new do
  # This step has no dependencies - runs first
  step :fetch_user, ->(result) {
    puts "  [#{Time.now.strftime('%H:%M:%S.%L')}] Fetching user..."
    sleep 0.1  # Simulate API call
    result.with_context(:user, { id: result.value, name: "John Doe" }).continue(result.value)
  }, depends_on: []

  # These two steps both depend on :fetch_user, so they can run in parallel
  step :fetch_orders, ->(result) {
    puts "  [#{Time.now.strftime('%H:%M:%S.%L')}] Fetching orders..."
    sleep 0.1  # Simulate API call
    result.with_context(:orders, [1, 2, 3]).continue(result.value)
  }, depends_on: [:fetch_user]

  step :fetch_products, ->(result) {
    puts "  [#{Time.now.strftime('%H:%M:%S.%L')}] Fetching products..."
    sleep 0.1  # Simulate API call
    result.with_context(:products, [:a, :b, :c]).continue(result.value)
  }, depends_on: [:fetch_user]

  # This step depends on both parallel steps - runs last
  step :calculate_total, ->(result) {
    puts "  [#{Time.now.strftime('%H:%M:%S.%L')}] Calculating total..."
    orders = result.context[:orders]
    products = result.context[:products]
    result.continue("Total: #{orders.size} orders, #{products.size} products")
  }, depends_on: [:fetch_orders, :fetch_products]
end

start_time = Time.now
result = pipeline.call_parallel(SimpleFlow::Result.new(123))
elapsed = Time.now - start_time

puts "\nResult: #{result.value}"
puts "User: #{result.context[:user]}"
puts "Orders: #{result.context[:orders]}"
puts "Products: #{result.context[:products]}"
puts "Execution time: #{(elapsed * 1000).round(2)}ms"
puts "(Should be ~200ms with parallel, ~400ms sequential)"
puts

# Example 2: Complex dependency graph
puts "\nExample 2: Complex Dependency Graph"
puts "-" * 60
puts

complex_pipeline = SimpleFlow::Pipeline.new do
  # Level 1: No dependencies
  step :validate_input, ->(result) {
    puts "  [Level 1] Validating input..."
    sleep 0.05
    result.with_context(:validated, true).continue(result.value)
  }, depends_on: []

  # Level 2: Depends on validation (can run in parallel with each other)
  step :check_inventory, ->(result) {
    puts "  [Level 2] Checking inventory..."
    sleep 0.05
    result.with_context(:inventory, :available).continue(result.value)
  }, depends_on: [:validate_input]

  step :check_pricing, ->(result) {
    puts "  [Level 2] Checking pricing..."
    sleep 0.05
    result.with_context(:price, 100).continue(result.value)
  }, depends_on: [:validate_input]

  step :check_shipping, ->(result) {
    puts "  [Level 2] Checking shipping..."
    sleep 0.05
    result.with_context(:shipping, 10).continue(result.value)
  }, depends_on: [:validate_input]

  # Level 3: Depends on inventory and pricing (runs after level 2)
  step :calculate_discount, ->(result) {
    puts "  [Level 3] Calculating discount..."
    sleep 0.05
    price = result.context[:price]
    result.with_context(:discount, price * 0.1).continue(result.value)
  }, depends_on: [:check_inventory, :check_pricing]

  # Level 4: Final step (depends on everything)
  step :finalize_order, ->(result) {
    puts "  [Level 4] Finalizing order..."
    price = result.context[:price]
    shipping = result.context[:shipping]
    discount = result.context[:discount]
    total = price + shipping - discount
    result.continue("Order total: $#{total}")
  }, depends_on: [:calculate_discount, :check_shipping]
end

puts "Dependency graph structure:"
puts "  Level 1: validate_input"
puts "  Level 2: check_inventory, check_pricing, check_shipping (parallel)"
puts "  Level 3: calculate_discount"
puts "  Level 4: finalize_order"
puts

start_time = Time.now
result2 = complex_pipeline.call_parallel(SimpleFlow::Result.new({ product_id: 456 }))
elapsed2 = Time.now - start_time

puts "\nResult: #{result2.value}"
puts "Context: #{result2.context}"
puts "Execution time: #{(elapsed2 * 1000).round(2)}ms"
puts

# Example 3: Visualizing the dependency graph
puts "\nExample 3: Dependency Graph Analysis"
puts "-" * 60
puts

# Create a graph manually to show analysis
graph = SimpleFlow::DependencyGraph.new(
  fetch_user: [],
  fetch_orders: [:fetch_user],
  fetch_products: [:fetch_user],
  fetch_reviews: [:fetch_user],
  calculate_stats: [:fetch_orders, :fetch_products],
  generate_report: [:calculate_stats, :fetch_reviews]
)

puts "Dependencies:"
graph.dependencies.each do |step, deps|
  deps_str = deps.empty? ? "(none)" : deps.join(", ")
  puts "  #{step}: #{deps_str}"
end

puts "\nSequential order:"
puts "  #{graph.order.join(' → ')}"

puts "\nParallel execution groups:"
graph.parallel_order.each_with_index do |group, index|
  puts "  Group #{index + 1}: #{group.join(', ')}"
end

puts "\nExecution strategy:"
puts "  • fetch_user runs first (no dependencies)"
puts "  • fetch_orders, fetch_products, fetch_reviews run in parallel"
puts "  • calculate_stats waits for orders and products"
puts "  • generate_report waits for stats and reviews"
puts

# Example 4: Error handling in parallel steps
puts "\nExample 4: Error Handling in Parallel Execution"
puts "-" * 60
puts

error_pipeline = SimpleFlow::Pipeline.new do
  step :task_a, ->(result) {
    puts "  Task A: Processing..."
    sleep 0.05
    result.with_context(:task_a, :success).continue(result.value)
  }, depends_on: []

  step :task_b, ->(result) {
    puts "  Task B: Processing..."
    sleep 0.05
    # Simulate a failure
    result.halt.with_error(:task_b, "Task B encountered an error")
  }, depends_on: []

  step :task_c, ->(result) {
    puts "  Task C: Processing..."
    sleep 0.05
    result.with_context(:task_c, :success).continue(result.value)
  }, depends_on: []

  step :final_step, ->(result) {
    puts "  Final step: This should not execute"
    result.continue("Completed")
  }, depends_on: [:task_a, :task_b, :task_c]
end

result3 = error_pipeline.call_parallel(SimpleFlow::Result.new(nil))

puts "\nResult:"
puts "  Continue? #{result3.continue?}"
puts "  Errors: #{result3.errors}"
puts "  Context: #{result3.context}"
puts "  Note: Pipeline halted when task_b failed, preventing final_step"

puts "\n" + "=" * 60
puts "Automatic parallel discovery examples completed!"
puts "=" * 60
