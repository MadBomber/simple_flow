#!/usr/bin/env ruby
# frozen_string_literal: true

# CONCEPT: How Dagwood could enhance SimpleFlow
# This is a demonstration of what SimpleFlow COULD look like with Dagwood integration

require_relative '../lib/simple_flow'

puts '=' * 80
puts 'Dagwood Integration Concept for SimpleFlow'
puts '=' * 80
puts

# ==============================================================================
# CURRENT SIMPLEFLOW: Manual Parallel Blocks
# ==============================================================================

puts "1. CURRENT APPROACH: Manual Parallel Blocks"
puts '-' * 80

current_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  Fetching user..."
    result.with_context(:user, { id: 123, name: 'Alice' }).continue(result.value)
  }

  # User must MANUALLY group parallel steps
  parallel do
    step ->(result) {
      puts "  Fetching orders..."
      sleep 0.05
      result.with_context(:orders, [1, 2, 3]).continue(result.value)
    }

    step ->(result) {
      puts "  Fetching preferences..."
      sleep 0.05
      result.with_context(:preferences, { theme: 'dark' }).continue(result.value)
    }
  end

  step ->(result) {
    puts "  Aggregating data..."
    result.continue("Aggregated")
  }
end

start = Time.now
current_pipeline.call(SimpleFlow::Result.new({ user_id: 123 }))
elapsed = Time.now - start

puts "\nCurrent Approach:"
puts "  - Manual parallel block declaration"
puts "  - Anonymous lambdas (hard to debug)"
puts "  - Implicit dependencies"
puts "  - Execution time: #{(elapsed * 1000).round(2)}ms"

# ==============================================================================
# CONCEPT: DAGWOOD-ENHANCED SIMPLEFLOW
# ==============================================================================

puts "\n\n2. CONCEPT: With Dagwood Integration"
puts '-' * 80

# This is what the API COULD look like
class UserDataPipeline
  # Conceptual API - how it could work with named steps and dependencies

  def self.build
    {
      fetch_user: {
        callable: ->(result) {
          puts "  Fetching user..."
          result.with_context(:user, { id: 123, name: 'Alice' }).continue(result.value)
        },
        depends_on: []
      },

      fetch_orders: {
        callable: ->(result) {
          puts "  Fetching orders..."
          sleep 0.05
          result.with_context(:orders, [1, 2, 3]).continue(result.value)
        },
        depends_on: [:fetch_user]  # Explicit dependency
      },

      fetch_preferences: {
        callable: ->(result) {
          puts "  Fetching preferences..."
          sleep 0.05
          result.with_context(:preferences, { theme: 'dark' }).continue(result.value)
        },
        depends_on: [:fetch_user]  # Explicit dependency
      },

      aggregate: {
        callable: ->(result) {
          puts "  Aggregating data..."
          result.continue("Aggregated")
        },
        depends_on: [:fetch_orders, :fetch_preferences]
      }
    }
  end

  def self.parallel_order
    # This is what Dagwood would automatically compute
    [
      [:fetch_user],  # Level 0
      [:fetch_orders, :fetch_preferences],  # Level 1 (parallel!)
      [:aggregate]  # Level 2
    ]
  end
end

puts "\nWith Dagwood concepts, the pipeline would:"
puts "  1. Declare explicit dependencies"
puts "  2. Automatically detect parallelizable steps"
puts "  3. Use named steps (better debugging)"
puts "\nAutomatically computed execution order:"
UserDataPipeline.parallel_order.each_with_index do |level, i|
  parallel = level.length > 1 ? " (PARALLEL)" : ""
  puts "  Level #{i}: #{level.inspect}#{parallel}"
end

# ==============================================================================
# CONCEPT: PIPELINE COMPOSITION
# ==============================================================================

puts "\n\n3. CONCEPT: Pipeline Composition"
puts '-' * 80

validation_flow = {
  validate_email: { depends_on: [] },
  validate_password: { depends_on: [] },
  check_age: { depends_on: [] }
}

user_creation_flow = {
  create_user: { depends_on: [:validate_email, :validate_password, :check_age] },
  send_welcome_email: { depends_on: [:create_user] },
  log_creation: { depends_on: [:create_user] }
}

# Merging would produce:
merged_flow_order = [
  [:validate_email, :validate_password, :check_age],  # Parallel validations
  [:create_user],
  [:send_welcome_email, :log_creation]  # Parallel post-creation
]

puts "Validation flow + User creation flow ="
merged_flow_order.each_with_index do |level, i|
  parallel = level.length > 1 ? " (PARALLEL)" : ""
  puts "  Level #{i}: #{level.inspect}#{parallel}"
end

# ==============================================================================
# CONCEPT: REVERSE/CLEANUP PIPELINES
# ==============================================================================

puts "\n\n4. CONCEPT: Reverse/Cleanup Pipelines"
puts '-' * 80

setup_order = [:allocate_resources, :connect_db, :load_data, :start_server]
cleanup_order = setup_order.reverse

puts "Setup order:   #{setup_order.inspect}"
puts "Cleanup order: #{cleanup_order.inspect}"
puts "\nUseful for:"
puts "  - Transaction rollback"
puts "  - Resource cleanup"
puts "  - Error recovery"

# ==============================================================================
# CONCEPT: SUBGRAPH EXTRACTION
# ==============================================================================

puts "\n\n5. CONCEPT: Subgraph Extraction"
puts '-' * 80

full_pipeline_steps = {
  fetch_user: { depends_on: [] },
  fetch_orders: { depends_on: [:fetch_user] },
  fetch_preferences: { depends_on: [:fetch_user] },
  calculate_total: { depends_on: [:fetch_orders] },
  apply_discount: { depends_on: [:calculate_total, :fetch_preferences] }
}

puts "Full pipeline: #{full_pipeline_steps.keys.inspect}"
puts "\nSubgraph for :calculate_total would include:"
puts "  [:fetch_user, :fetch_orders, :calculate_total]"
puts "\nBenefits:"
puts "  - Run only what's needed"
puts "  - Faster execution"
puts "  - Easier testing"

# ==============================================================================
# BENEFITS SUMMARY
# ==============================================================================

puts "\n\n" + '=' * 80
puts 'BENEFITS OF DAGWOOD INTEGRATION'
puts '=' * 80

benefits = [
  "✅ Automatic parallel detection (no manual parallel blocks)",
  "✅ Explicit dependencies (clearer code)",
  "✅ Named steps (better debugging)",
  "✅ Pipeline composition (reusable components)",
  "✅ Reverse pipelines (cleanup/teardown)",
  "✅ Subgraph extraction (partial execution)",
  "✅ Better testability (test steps by name)",
  "✅ Self-documenting (dependencies are visible)"
]

benefits.each { |b| puts "  #{b}" }

puts "\n" + '=' * 80
puts 'BACKWARD COMPATIBILITY'
puts '=' * 80
puts "  All existing SimpleFlow code would continue to work!"
puts "  Users can adopt new features gradually."
puts '=' * 80
