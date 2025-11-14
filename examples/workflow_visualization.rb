#!/usr/bin/env ruby
# frozen_string_literal: true

# This example demonstrates workflow visualization using Graphviz DOT format.
# You can generate visual diagrams of your SimpleFlow pipelines to understand
# dependencies, parallelization, and execution flow.

require_relative '../lib/simple_flow'

puts '=' * 80
puts 'SimpleFlow Workflow Visualization'
puts '=' * 80
puts

# ==============================================================================
# EXAMPLE 1: Simple E-Commerce Order Processing Pipeline
# ==============================================================================

puts "EXAMPLE 1: E-Commerce Order Processing"
puts '-' * 80
puts

order_pipeline = SimpleFlow::Pipeline.new do
  # Initial validation
  step :validate_order, ->(result) {
    result.with_context(:validated, true).continue(result.value)
  }

  # Parallel data fetching (no dependencies between them)
  step :fetch_inventory, ->(result) {
    result.with_context(:inventory, { available: 100 }).continue(result.value)
  }, depends_on: [:validate_order]

  step :fetch_pricing, ->(result) {
    result.with_context(:price, 99.99).continue(result.value)
  }, depends_on: [:validate_order]

  step :check_user_credit, ->(result) {
    result.with_context(:credit_ok, true).continue(result.value)
  }, depends_on: [:validate_order]

  # Process payment (depends on pricing and credit check)
  step :process_payment, ->(result) {
    result.with_context(:payment_id, 'PAY-12345').continue(result.value)
  }, depends_on: [:fetch_pricing, :check_user_credit]

  # Reserve inventory (depends on inventory check and payment)
  step :reserve_inventory, ->(result) {
    result.with_context(:reserved, true).continue(result.value)
  }, depends_on: [:fetch_inventory, :process_payment]

  # Final confirmation
  step :send_confirmation, ->(result) {
    result.continue("Order #{result.value} confirmed")
  }, depends_on: [:reserve_inventory]
end

# Generate basic DOT file
dot_basic = order_pipeline.to_dot(title: 'E-Commerce Order Processing')
File.write('order_pipeline.dot', dot_basic)

puts "✓ Generated: order_pipeline.dot"
puts "\nTo create a PNG image, run:"
puts "  dot -Tpng order_pipeline.dot -o order_pipeline.png"
puts

# Generate with level highlighting
dot_levels = order_pipeline.to_dot(
  title: 'E-Commerce Order Processing (with levels)',
  show_levels: true
)
File.write('order_pipeline_levels.dot', dot_levels)

puts "✓ Generated: order_pipeline_levels.dot (with parallel level colors)"
puts

# Show the parallel execution order
puts "Parallel Execution Order:"
order_pipeline.parallel_order.each_with_index do |level, idx|
  marker = level.size > 1 ? " (PARALLEL)" : ""
  puts "  Level #{idx}: #{level.inspect}#{marker}"
end
puts

# ==============================================================================
# EXAMPLE 2: Data Processing Pipeline
# ==============================================================================

puts "\nEXAMPLE 2: Data Processing Pipeline"
puts '-' * 80
puts

data_pipeline = SimpleFlow::Pipeline.new do
  step :load_data, ->(result) {
    result.continue(result.value)
  }

  # Parallel transformations
  step :clean_data, ->(result) { result.continue(result.value) }, depends_on: [:load_data]
  step :validate_schema, ->(result) { result.continue(result.value) }, depends_on: [:load_data]
  step :extract_metadata, ->(result) { result.continue(result.value) }, depends_on: [:load_data]

  # Aggregation (depends on all transformations)
  step :aggregate, ->(result) { result.continue(result.value) },
       depends_on: [:clean_data, :validate_schema, :extract_metadata]

  # Final steps
  step :save_to_database, ->(result) { result.continue(result.value) }, depends_on: [:aggregate]
  step :generate_report, ->(result) { result.continue(result.value) }, depends_on: [:aggregate]

  # Notification (depends on both save and report)
  step :send_notification, ->(result) { result.continue(result.value) },
       depends_on: [:save_to_database, :generate_report]
end

dot = data_pipeline.to_dot(
  title: 'Data Processing Pipeline',
  show_levels: true,
  rankdir: 'LR'  # Left to right layout
)
File.write('data_pipeline.dot', dot)

puts "✓ Generated: data_pipeline.dot (left-to-right layout)"
puts

# ==============================================================================
# EXAMPLE 3: Complex ML Training Pipeline
# ==============================================================================

puts "\nEXAMPLE 3: Machine Learning Training Pipeline"
puts '-' * 80
puts

ml_pipeline = SimpleFlow::Pipeline.new do
  # Data preparation
  step :fetch_training_data, ->(result) { result.continue(result.value) }
  step :fetch_validation_data, ->(result) { result.continue(result.value) }

  # Feature engineering (parallel)
  step :extract_features_train, ->(result) { result.continue(result.value) },
       depends_on: [:fetch_training_data]
  step :extract_features_val, ->(result) { result.continue(result.value) },
       depends_on: [:fetch_validation_data]

  # Normalization
  step :normalize_train, ->(result) { result.continue(result.value) },
       depends_on: [:extract_features_train]
  step :normalize_val, ->(result) { result.continue(result.value) },
       depends_on: [:extract_features_val]

  # Model training
  step :train_model, ->(result) { result.continue(result.value) },
       depends_on: [:normalize_train]

  # Evaluation
  step :evaluate_model, ->(result) { result.continue(result.value) },
       depends_on: [:train_model, :normalize_val]

  # Parallel deployment tasks
  step :save_model, ->(result) { result.continue(result.value) },
       depends_on: [:evaluate_model]
  step :generate_metrics, ->(result) { result.continue(result.value) },
       depends_on: [:evaluate_model]
  step :create_documentation, ->(result) { result.continue(result.value) },
       depends_on: [:evaluate_model]

  # Final step
  step :deploy_to_production, ->(result) { result.continue(result.value) },
       depends_on: [:save_model, :generate_metrics, :create_documentation]
end

dot = ml_pipeline.to_dot(
  title: 'ML Training Pipeline',
  show_levels: true
)
File.write('ml_pipeline.dot', dot)

puts "✓ Generated: ml_pipeline.dot"
puts

# ==============================================================================
# EXAMPLE 4: Direct DependencyGraph Usage
# ==============================================================================

puts "\nEXAMPLE 4: Using DependencyGraph Directly"
puts '-' * 80
puts

graph = SimpleFlow::DependencyGraph.new

graph.add_step(:init, ->(r) { r.continue(r.value) })
graph.add_step(:step_a, ->(r) { r.continue(r.value) }, depends_on: [:init])
graph.add_step(:step_b, ->(r) { r.continue(r.value) }, depends_on: [:init])
graph.add_step(:step_c, ->(r) { r.continue(r.value) }, depends_on: [:step_a, :step_b])

dot = graph.to_dot(title: 'Simple Dependency Graph', show_levels: true)
File.write('simple_graph.dot', dot)

puts "✓ Generated: simple_graph.dot"
puts

# ==============================================================================
# EXAMPLE 5: Subgraph Visualization
# ==============================================================================

puts "\nEXAMPLE 5: Subgraph Visualization"
puts '-' * 80
puts

# Extract subgraph for just the payment processing part
payment_subgraph = order_pipeline.subgraph(:process_payment)

dot = payment_subgraph.to_dot(
  title: 'Payment Processing Subgraph',
  show_levels: true
)
File.write('payment_subgraph.dot', dot)

puts "✓ Generated: payment_subgraph.dot"
puts "  (Only shows steps needed for :process_payment)"
puts

# ==============================================================================
# SUMMARY
# ==============================================================================

puts '=' * 80
puts 'SUMMARY'
puts '=' * 80
puts
puts "Generated DOT files:"
puts "  • order_pipeline.dot - Basic e-commerce workflow"
puts "  • order_pipeline_levels.dot - Same with level highlighting"
puts "  • data_pipeline.dot - Data processing (left-to-right layout)"
puts "  • ml_pipeline.dot - ML training workflow"
puts "  • simple_graph.dot - Simple dependency graph"
puts "  • payment_subgraph.dot - Extracted subgraph"
puts
puts "To visualize (requires Graphviz installed):"
puts "  dot -Tpng <file>.dot -o <file>.png    # PNG image"
puts "  dot -Tsvg <file>.dot -o <file>.svg    # SVG image"
puts "  dot -Tpdf <file>.dot -o <file>.pdf    # PDF document"
puts
puts "DOT file options:"
puts "  title: 'My Pipeline'       # Graph title"
puts "  show_levels: true          # Color nodes by execution level"
puts "  rankdir: 'LR'              # Layout: TB (top-bottom) or LR (left-right)"
puts
puts "Benefits:"
puts "  ✓ Visualize complex dependencies"
puts "  ✓ Identify parallel execution opportunities"
puts "  ✓ Debug workflow issues"
puts "  ✓ Document pipeline architecture"
puts "  ✓ Share workflow design with team"
puts '=' * 80
