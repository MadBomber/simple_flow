#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Direct pipeline visualization - no need to recreate dependency structure!

puts "=" * 60
puts "Direct Pipeline Visualization"
puts "=" * 60
puts

# Example 1: Visualize directly from pipeline
puts "Example 1: Simple Pipeline Visualization"
puts "-" * 60
puts

pipeline = SimpleFlow::Pipeline.new do
  step :validate, ->(result) {
    result.with_context(:validated, true).continue(result.value)
  }, depends_on: []

  step :fetch_data, ->(result) {
    result.with_context(:data, [1, 2, 3]).continue(result.value)
  }, depends_on: [:validate]

  step :process_data, ->(result) {
    result.continue(result.value * 2)
  }, depends_on: [:fetch_data]
end

# Visualize directly - no manual graph creation needed!
puts pipeline.visualize_ascii
puts

# Example 2: E-commerce pipeline with parallel steps
puts "\n" + "=" * 60
puts "Example 2: E-commerce Pipeline (Automatic Visualization)"
puts "=" * 60
puts

ecommerce_pipeline = SimpleFlow::Pipeline.new do
  step :validate_order, ->(result) {
    result.continue(result.value)
  }, depends_on: []

  # These will run in parallel
  step :check_inventory, ->(result) {
    result.with_context(:inventory, :ok).continue(result.value)
  }, depends_on: [:validate_order]

  step :calculate_shipping, ->(result) {
    result.with_context(:shipping, 10).continue(result.value)
  }, depends_on: [:validate_order]

  step :calculate_totals, ->(result) {
    result.continue(result.value)
  }, depends_on: [:check_inventory, :calculate_shipping]

  step :process_payment, ->(result) {
    result.continue(result.value)
  }, depends_on: [:calculate_totals]

  step :reserve_inventory, ->(result) {
    result.continue(result.value)
  }, depends_on: [:process_payment]

  step :create_shipment, ->(result) {
    result.continue(result.value)
  }, depends_on: [:reserve_inventory]

  # These will run in parallel
  step :send_email, ->(result) {
    result.continue(result.value)
  }, depends_on: [:create_shipment]

  step :send_sms, ->(result) {
    result.continue(result.value)
  }, depends_on: [:create_shipment]

  step :finalize_order, ->(result) {
    result.continue("Order complete!")
  }, depends_on: [:send_email, :send_sms]
end

# Display the visualization
puts ecommerce_pipeline.visualize_ascii
puts

# Example 3: Get execution plan
puts "\n" + "=" * 60
puts "Example 3: Execution Plan (Direct from Pipeline)"
puts "=" * 60
puts

puts ecommerce_pipeline.execution_plan
puts

# Example 4: Export to different formats
puts "\n" + "=" * 60
puts "Example 4: Export Formats (Direct from Pipeline)"
puts "=" * 60
puts

# Export to Graphviz DOT
File.write('pipeline_graph.dot', ecommerce_pipeline.visualize_dot)
puts "✓ Exported to Graphviz DOT: pipeline_graph.dot"
puts "  Generate image: dot -Tpng pipeline_graph.dot -o pipeline.png"
puts

# Export to Mermaid
File.write('pipeline_graph.mmd', ecommerce_pipeline.visualize_mermaid)
puts "✓ Exported to Mermaid: pipeline_graph.mmd"
puts "  View at: https://mermaid.live/"
puts

# Export to HTML (need the visualizer object for this)
if visualizer = ecommerce_pipeline.visualize
  File.write('pipeline_graph.html', visualizer.to_html(title: "E-commerce Pipeline"))
  puts "✓ Exported to HTML: pipeline_graph.html"
  puts "  Open in browser for interactive visualization"
end
puts

# Example 5: ETL Pipeline
puts "\n" + "=" * 60
puts "Example 5: ETL Pipeline Visualization"
puts "=" * 60
puts

etl_pipeline = SimpleFlow::Pipeline.new do
  # Extract phase - all run in parallel
  step :extract_users, ->(result) {
    result.with_context(:users, []).continue(result.value)
  }, depends_on: []

  step :extract_orders, ->(result) {
    result.with_context(:orders, []).continue(result.value)
  }, depends_on: []

  step :extract_products, ->(result) {
    result.with_context(:products, []).continue(result.value)
  }, depends_on: []

  # Transform phase - all run in parallel after extraction
  step :transform_users, ->(result) {
    result.continue(result.value)
  }, depends_on: [:extract_users]

  step :transform_orders, ->(result) {
    result.continue(result.value)
  }, depends_on: [:extract_orders]

  step :transform_products, ->(result) {
    result.continue(result.value)
  }, depends_on: [:extract_products]

  # Aggregate phase - can run in parallel
  step :aggregate_user_stats, ->(result) {
    result.continue(result.value)
  }, depends_on: [:transform_users, :transform_orders]

  step :aggregate_category_stats, ->(result) {
    result.continue(result.value)
  }, depends_on: [:transform_products]

  # Validate
  step :validate_data, ->(result) {
    result.continue(result.value)
  }, depends_on: [:aggregate_user_stats]

  # Load
  step :prepare_output, ->(result) {
    result.continue("ETL Complete!")
  }, depends_on: [:validate_data, :aggregate_category_stats]
end

puts etl_pipeline.execution_plan
puts

# Example 6: Check if pipeline can be visualized
puts "\n" + "=" * 60
puts "Example 6: Checking Visualization Availability"
puts "=" * 60
puts

# Pipeline with named steps - can be visualized
named_pipeline = SimpleFlow::Pipeline.new do
  step :step_a, ->(r) { r.continue(r.value) }, depends_on: []
  step :step_b, ->(r) { r.continue(r.value) }, depends_on: [:step_a]
end

# Pipeline with unnamed steps - cannot be auto-visualized
unnamed_pipeline = SimpleFlow::Pipeline.new do
  step ->(r) { r.continue(r.value) }
  step ->(r) { r.continue(r.value) }
end

puts "Named pipeline has dependency graph? #{!named_pipeline.dependency_graph.nil?}"
puts "Unnamed pipeline has dependency graph? #{!unnamed_pipeline.dependency_graph.nil?}"
puts
puts "Note: Only pipelines with named steps and dependencies can be auto-visualized"
puts

# Example 7: Working with the dependency graph directly
puts "\n" + "=" * 60
puts "Example 7: Advanced - Access Dependency Graph"
puts "=" * 60
puts

if graph = ecommerce_pipeline.dependency_graph
  puts "Pipeline dependency information:"
  puts "  Total steps: #{graph.dependencies.size}"
  puts "  Execution phases: #{graph.parallel_order.size}"
  puts "  Parallel groups:"
  graph.parallel_order.each_with_index do |group, idx|
    puts "    Phase #{idx + 1}: #{group.join(', ')}"
  end
end
puts

# Example 8: Compare different pipeline structures
puts "\n" + "=" * 60
puts "Example 8: Pipeline Structure Comparison"
puts "=" * 60
puts

# Linear pipeline
linear = SimpleFlow::Pipeline.new do
  step :step1, ->(r) { r.continue(r.value) }, depends_on: []
  step :step2, ->(r) { r.continue(r.value) }, depends_on: [:step1]
  step :step3, ->(r) { r.continue(r.value) }, depends_on: [:step2]
  step :step4, ->(r) { r.continue(r.value) }, depends_on: [:step3]
end

# Parallel pipeline
parallel = SimpleFlow::Pipeline.new do
  step :start, ->(r) { r.continue(r.value) }, depends_on: []
  step :task1, ->(r) { r.continue(r.value) }, depends_on: [:start]
  step :task2, ->(r) { r.continue(r.value) }, depends_on: [:start]
  step :task3, ->(r) { r.continue(r.value) }, depends_on: [:start]
  step :end, ->(r) { r.continue(r.value) }, depends_on: [:task1, :task2, :task3]
end

puts "Linear Pipeline:"
puts linear.execution_plan
puts

puts "\nParallel Pipeline:"
puts parallel.execution_plan
puts

puts "=" * 60
puts "Direct pipeline visualization completed!"
puts
puts "Key Takeaway:"
puts "  No need to manually recreate dependency structures!"
puts "  Just call pipeline.visualize_ascii, pipeline.visualize_dot, etc."
puts
puts "Generated files:"
puts "  - pipeline_graph.dot"
puts "  - pipeline_graph.mmd"
puts "  - pipeline_graph.html"
puts "=" * 60
