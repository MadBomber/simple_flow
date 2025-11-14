#!/usr/bin/env ruby
# frozen_string_literal: true

# This example demonstrates advanced DependencyGraph features:
# - Automatic parallel detection
# - Subgraph extraction
# - Graph merging/composition
# - Reverse execution order (for cleanup/teardown)

require_relative '../lib/simple_flow'

puts '=' * 80
puts 'SimpleFlow DependencyGraph: Advanced Features'
puts '=' * 80
puts

# ==============================================================================
# FEATURE 1: AUTOMATIC PARALLEL DETECTION
# ==============================================================================

puts "FEATURE 1: Automatic Parallel Detection"
puts '-' * 80
puts

graph1 = SimpleFlow::DependencyGraph.new

# Define a multi-level dependency graph
graph1.add_step(:fetch_user, ->(result) {
  puts "  Fetching user..."
  result.with_context(:user, { id: 1 }).continue(result.value)
})

# These two depend on fetch_user, so they'll run in parallel
graph1.add_step(:fetch_orders, ->(result) {
  puts "  Fetching orders..."
  result.with_context(:orders, [1, 2]).continue(result.value)
}, depends_on: [:fetch_user])

graph1.add_step(:fetch_preferences, ->(result) {
  puts "  Fetching preferences..."
  result.with_context(:prefs, { theme: 'dark' }).continue(result.value)
}, depends_on: [:fetch_user])

# These two depend on different parent steps, but can run in parallel
graph1.add_step(:calculate_total, ->(result) {
  puts "  Calculating total..."
  result.with_context(:total, 100).continue(result.value)
}, depends_on: [:fetch_orders])

graph1.add_step(:apply_theme, ->(result) {
  puts "  Applying theme..."
  result.continue(result.value)
}, depends_on: [:fetch_preferences])

# This depends on both calculate_total and apply_theme
graph1.add_step(:render_page, ->(result) {
  puts "  Rendering page..."
  result.continue("Page rendered")
}, depends_on: [:calculate_total, :apply_theme])

puts "Dependency graph structure:"
puts "  Steps: #{graph1.steps.keys.inspect}"
puts "\nDependencies:"
graph1.dependencies.each do |step, deps|
  puts "  #{step} depends on: #{deps.inspect}"
end

puts "\nAutomatically computed parallel execution order:"
parallel_order = graph1.parallel_order
parallel_order.each_with_index do |level, i|
  parallel_marker = level.length > 1 ? " (PARALLEL)" : ""
  puts "  Level #{i}: #{level.inspect}#{parallel_marker}"
end

puts "\nExecuting graph..."
result1 = graph1.execute(SimpleFlow::Result.new("initial"))
puts "Final result: #{result1.value}"
puts

# ==============================================================================
# FEATURE 2: SUBGRAPH EXTRACTION
# ==============================================================================

puts "\n" + "FEATURE 2: Subgraph Extraction"
puts '-' * 80
puts "Extract only the steps needed to compute a specific result"
puts

graph2 = SimpleFlow::DependencyGraph.new

graph2.add_step(:step_a, ->(r) {
  puts "  Executing step A"
  r.continue(r.value)
})

graph2.add_step(:step_b, ->(r) {
  puts "  Executing step B"
  r.continue(r.value)
}, depends_on: [:step_a])

graph2.add_step(:step_c, ->(r) {
  puts "  Executing step C"
  r.continue(r.value)
}, depends_on: [:step_a])

graph2.add_step(:step_d, ->(r) {
  puts "  Executing step D"
  r.continue(r.value)
}, depends_on: [:step_b])

graph2.add_step(:step_e, ->(r) {
  puts "  Executing step E"
  r.continue(r.value)
}, depends_on: [:step_c])

puts "Full graph has steps: #{graph2.steps.keys.inspect}"
puts

# Extract subgraph for step_d (includes only step_a, step_b, step_d)
subgraph = graph2.subgraph(:step_d)
puts "Subgraph for :step_d includes: #{subgraph.steps.keys.inspect}"
puts "  (Only the steps needed to compute step_d)"
puts "\nExecuting subgraph:"
subgraph.execute(SimpleFlow::Result.new("sub"))
puts

# ==============================================================================
# FEATURE 3: GRAPH MERGING/COMPOSITION
# ==============================================================================

puts "\n" + "FEATURE 3: Graph Merging/Composition"
puts '-' * 80
puts "Combine multiple graphs to build complex pipelines from reusable components"
puts

# Validation graph (reusable component)
validation_graph = SimpleFlow::DependencyGraph.new
validation_graph.add_step(:validate_email, ->(r) {
  puts "  Validating email..."
  r.continue(r.value)
})
validation_graph.add_step(:validate_password, ->(r) {
  puts "  Validating password..."
  r.continue(r.value)
})

# User creation graph (reusable component)
user_creation_graph = SimpleFlow::DependencyGraph.new
user_creation_graph.add_step(:create_user, ->(r) {
  puts "  Creating user..."
  r.continue(r.value)
}, depends_on: [:validate_email, :validate_password])
user_creation_graph.add_step(:send_welcome_email, ->(r) {
  puts "  Sending welcome email..."
  r.continue(r.value)
}, depends_on: [:create_user])

# Merge the graphs
merged_graph = validation_graph.merge(user_creation_graph)

puts "Validation graph: #{validation_graph.steps.keys.inspect}"
puts "User creation graph: #{user_creation_graph.steps.keys.inspect}"
puts "Merged graph: #{merged_graph.steps.keys.inspect}"
puts "\nMerged graph execution order:"
merged_graph.parallel_order.each_with_index do |level, i|
  parallel_marker = level.length > 1 ? " (PARALLEL)" : ""
  puts "  Level #{i}: #{level.inspect}#{parallel_marker}"
end

puts "\nExecuting merged graph:"
merged_graph.execute(SimpleFlow::Result.new("user@example.com"))
puts

# ==============================================================================
# FEATURE 4: REVERSE ORDER (CLEANUP/TEARDOWN)
# ==============================================================================

puts "\n" + "FEATURE 4: Reverse Order (Cleanup/Teardown)"
puts '-' * 80
puts "Execute steps in reverse order for cleanup operations"
puts

setup_graph = SimpleFlow::DependencyGraph.new

setup_graph.add_step(:allocate_memory, ->(r) {
  puts "  [Setup] Allocating memory..."
  r.continue(r.value)
})

setup_graph.add_step(:open_connection, ->(r) {
  puts "  [Setup] Opening database connection..."
  r.continue(r.value)
}, depends_on: [:allocate_memory])

setup_graph.add_step(:load_data, ->(r) {
  puts "  [Setup] Loading data..."
  r.continue(r.value)
}, depends_on: [:open_connection])

setup_graph.add_step(:start_server, ->(r) {
  puts "  [Setup] Starting server..."
  r.continue(r.value)
}, depends_on: [:load_data])

setup_order = setup_graph.order
teardown_order = setup_order.reverse

puts "Setup order:    #{setup_order.inspect}"
puts "Teardown order: #{teardown_order.inspect}"
puts "\nNote: Reverse order ensures proper cleanup (close what was opened last first)"
puts

# ==============================================================================
# FEATURE 5: CYCLE DETECTION
# ==============================================================================

puts "\n" + "FEATURE 5: Cycle Detection"
puts '-' * 80
puts "DependencyGraph detects circular dependencies"
puts

begin
  cycle_graph = SimpleFlow::DependencyGraph.new
  cycle_graph.add_step(:step_x, ->(r) { r.continue(r.value) })
  cycle_graph.add_step(:step_y, ->(r) { r.continue(r.value) }, depends_on: [:step_x])
  cycle_graph.add_step(:step_z, ->(r) { r.continue(r.value) }, depends_on: [:step_y])
  # Create a cycle: z -> y -> x -> z
  cycle_graph.add_step(:step_x, ->(r) { r.continue(r.value) }, depends_on: [:step_z])

  cycle_graph.order  # This will raise an error
rescue => e
  puts "  ✅ Cycle detected! Error: #{e.class}"
  puts "     #{e.message}"
end

# ==============================================================================
# SUMMARY
# ==============================================================================

puts "\n" + '=' * 80
puts 'DEPENDENCY GRAPH BENEFITS'
puts '=' * 80

benefits = [
  "✅ Automatic parallel detection - no manual parallel blocks needed",
  "✅ Named steps - better debugging and error messages",
  "✅ Explicit dependencies - self-documenting code",
  "✅ Subgraph extraction - run only what's needed",
  "✅ Graph composition - build from reusable components",
  "✅ Reverse order - easy cleanup/teardown logic",
  "✅ Cycle detection - prevents infinite loops",
  "✅ Topological sorting - guaranteed correct execution order"
]

benefits.each { |b| puts "  #{b}" }

puts "\n" + '=' * 80
puts 'WHEN TO USE DEPENDENCY GRAPHS'
puts '=' * 80

puts "\nUse DependencyGraph directly when you need:"
puts "  • Complex multi-level dependencies"
puts "  • Reusable pipeline components (composition)"
puts "  • Subgraph extraction for partial execution"
puts "  • Reverse execution order for cleanup"
puts "  • Better debugging (named steps with clear dependencies)"

puts "\nUse manual Pipeline.parallel blocks when you need:"
puts "  • Simple, obvious parallel sections"
puts "  • Anonymous lambdas without names"
puts "  • Quick prototyping"

puts "\nBest practice: Start with manual parallel blocks, migrate to"
puts "               DependencyGraph as complexity grows"
puts '=' * 80
