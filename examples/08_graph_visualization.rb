#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'
require 'timecop'
Timecop.travel(Time.local(2001, 9, 11, 7, 0, 0))

# Graph visualization examples

puts "=" * 60
puts "Dependency Graph Visualization"
puts "=" * 60
puts

# Example 1: Simple graph
puts "Example 1: Simple Dependency Graph"
puts "-" * 60
puts

simple_graph = SimpleFlow::DependencyGraph.new(
  step_a: [],
  step_b: [:step_a],
  step_c: [:step_a],
  step_d: [:step_b, :step_c]
)

visualizer = SimpleFlow::DependencyGraphVisualizer.new(simple_graph)

puts visualizer.to_ascii
puts

# Example 2: Complex real-world graph
puts "\n" + "=" * 60
puts "Example 2: E-commerce Order Processing Graph"
puts "=" * 60
puts

ecommerce_graph = SimpleFlow::DependencyGraph.new(
  validate_order: [],
  check_inventory: [:validate_order],
  calculate_shipping: [:validate_order],
  calculate_totals: [:check_inventory, :calculate_shipping],
  process_payment: [:calculate_totals],
  reserve_inventory: [:process_payment],
  create_shipment: [:reserve_inventory],
  send_email: [:create_shipment],
  send_sms: [:create_shipment],
  finalize_order: [:send_email, :send_sms]
)

ecommerce_visualizer = SimpleFlow::DependencyGraphVisualizer.new(ecommerce_graph)

puts ecommerce_visualizer.to_ascii
puts

# Example 3: Execution plan
puts "\n" + "=" * 60
puts "Example 3: Execution Plan"
puts "=" * 60
puts

puts ecommerce_visualizer.to_execution_plan
puts

# Example 4: ETL Pipeline graph
puts "\n" + "=" * 60
puts "Example 4: ETL Pipeline Graph"
puts "=" * 60
puts

etl_graph = SimpleFlow::DependencyGraph.new(
  extract_users: [],
  extract_orders: [],
  extract_products: [],
  transform_users: [:extract_users],
  transform_orders: [:extract_orders],
  transform_products: [:extract_products],
  aggregate_user_stats: [:transform_users, :transform_orders],
  aggregate_category_stats: [:transform_products],
  validate_data: [:aggregate_user_stats],
  prepare_output: [:validate_data, :aggregate_category_stats]
)

etl_visualizer = SimpleFlow::DependencyGraphVisualizer.new(etl_graph)

puts etl_visualizer.to_execution_plan
puts

# Example 5: Export formats
puts "\n" + "=" * 60
puts "Example 5: Exporting to Different Formats"
puts "=" * 60
puts

# Export to Graphviz DOT format
dot_output = ecommerce_visualizer.to_dot(include_groups: true, orientation: 'TB')
File.write('ecommerce_graph.dot', dot_output)
puts "✓ Exported to Graphviz DOT format: ecommerce_graph.dot"
puts "  To generate PNG: dot -Tpng ecommerce_graph.dot -o ecommerce_graph.png"
puts "  To generate SVG: dot -Tsvg ecommerce_graph.dot -o ecommerce_graph.svg"
puts

# Export to Mermaid format
mermaid_output = ecommerce_visualizer.to_mermaid
File.write('ecommerce_graph.mmd', mermaid_output)
puts "✓ Exported to Mermaid format: ecommerce_graph.mmd"
puts "  View at: https://mermaid.live/"
puts

# Export to HTML
html_output = ecommerce_visualizer.to_html(title: "E-commerce Order Processing Graph")
File.write('ecommerce_graph.html', html_output)
puts "✓ Exported to interactive HTML: ecommerce_graph.html"
puts "  Open in browser to view interactive graph"
puts

# Show the DOT format
puts "\nGraphviz DOT Format Preview:"
puts "-" * 60
puts dot_output.lines.take(20).join
puts "... (truncated)"
puts

# Show the Mermaid format
puts "\nMermaid Format Preview:"
puts "-" * 60
puts mermaid_output.lines.take(15).join
puts "... (truncated)"
puts

# Example 6: Visualizing a Pipeline (Direct Method - RECOMMENDED)
puts "\n" + "=" * 60
puts "Example 6: Visualizing a Pipeline Directly"
puts "=" * 60
puts

pipeline = SimpleFlow::Pipeline.new do
  step :fetch_config, ->(result) {
    result.with_context(:config, {}).continue(result.value)
  }, depends_on: :none

  step :load_data, ->(result) {
    result.with_context(:data, []).continue(result.value)
  }, depends_on: [:fetch_config]

  step :validate_schema, ->(result) {
    result.continue(result.value)
  }, depends_on: [:load_data]

  step :enrich_data, ->(result) {
    result.continue(result.value)
  }, depends_on: [:load_data]

  step :save_results, ->(result) {
    result.continue(result.value)
  }, depends_on: [:validate_schema, :enrich_data]
end

# RECOMMENDED: Visualize directly from the pipeline
puts "Pipeline Dependency Graph:"
puts
puts pipeline.visualize_ascii
puts

# Alternative (manual approach - not recommended):
# pipeline_graph = SimpleFlow::DependencyGraph.new(pipeline.step_dependencies)
# pipeline_visualizer = SimpleFlow::DependencyGraphVisualizer.new(pipeline_graph)
# puts pipeline_visualizer.to_ascii

# Example 7: Comparing different graph structures
puts "\n" + "=" * 60
puts "Example 7: Graph Structure Comparison"
puts "=" * 60
puts

# Linear pipeline (no parallelism)
linear_graph = SimpleFlow::DependencyGraph.new(
  step1: [],
  step2: [:step1],
  step3: [:step2],
  step4: [:step3],
  step5: [:step4]
)

# Fan-out/fan-in (maximum parallelism)
fanout_graph = SimpleFlow::DependencyGraph.new(
  start: [],
  task1: [:start],
  task2: [:start],
  task3: [:start],
  task4: [:start],
  end: [:task1, :task2, :task3, :task4]
)

puts "Linear Pipeline (Sequential):"
puts SimpleFlow::DependencyGraphVisualizer.new(linear_graph).to_execution_plan
puts

puts "\nFan-out/Fan-in Pipeline (Parallel):"
puts SimpleFlow::DependencyGraphVisualizer.new(fanout_graph).to_execution_plan
puts

# Example 8: Graph statistics
puts "\n" + "=" * 60
puts "Example 8: Graph Analytics"
puts "=" * 60
puts

def analyze_graph(graph, name)
  parallel_groups = graph.parallel_order
  total_steps = graph.dependencies.size
  max_parallel = parallel_groups.map(&:size).max

  puts "#{name}:"
  puts "  Total steps: #{total_steps}"
  puts "  Execution phases: #{parallel_groups.size}"
  puts "  Max parallel steps: #{max_parallel}"
  puts "  Theoretical speedup: #{(total_steps.to_f / parallel_groups.size).round(2)}x"
  puts "  Parallelization ratio: #{((max_parallel.to_f / total_steps) * 100).round(1)}%"
  puts
end

analyze_graph(simple_graph, "Simple Graph")
analyze_graph(ecommerce_graph, "E-commerce Graph")
analyze_graph(etl_graph, "ETL Graph")
analyze_graph(linear_graph, "Linear Graph")
analyze_graph(fanout_graph, "Fan-out/Fan-in Graph")

puts "=" * 60
puts "Graph visualization examples completed!"
puts
puts "Generated files:"
puts "  - ecommerce_graph.dot (Graphviz format)"
puts "  - ecommerce_graph.mmd (Mermaid format)"
puts "  - ecommerce_graph.html (Interactive HTML)"
puts
puts "To generate images with Graphviz:"
puts "  $ dot -Tpng ecommerce_graph.dot -o ecommerce_graph.png"
puts "  $ dot -Tsvg ecommerce_graph.dot -o ecommerce_graph.svg"
puts "  $ dot -Tpdf ecommerce_graph.dot -o ecommerce_graph.pdf"
puts
puts "To view Mermaid diagram:"
puts "  1. Visit https://mermaid.live/"
puts "  2. Paste contents of ecommerce_graph.mmd"
puts "  3. Or use Mermaid CLI: mmdc -i ecommerce_graph.mmd -o graph.png"
puts "=" * 60
