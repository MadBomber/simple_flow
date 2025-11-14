#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Example: Parallel Data Fetching
# This example demonstrates how to fetch data from multiple sources concurrently
# to improve performance.

# Simulate API calls with sleep
def fetch_user_profile(user_id)
  sleep 0.1 # Simulate network delay
  { id: user_id, name: "User #{user_id}", email: "user#{user_id}@example.com" }
end

def fetch_user_orders(user_id)
  sleep 0.1 # Simulate network delay
  [
    { id: 1, total: 99.99, status: "delivered" },
    { id: 2, total: 149.99, status: "pending" }
  ]
end

def fetch_user_preferences(user_id)
  sleep 0.1 # Simulate network delay
  { theme: "dark", notifications: true, language: "en" }
end

def fetch_analytics(user_id)
  sleep 0.1 # Simulate network delay
  { page_views: 150, sessions: 45, last_login: Time.now - 3600 }
end

# Build a pipeline that fetches all user data
pipeline = SimpleFlow::Pipeline.new do
  # First, validate the user_id
  step ->(result) {
    user_id = result.value
    if user_id.nil? || user_id <= 0
      result.halt(nil).with_error(:validation, "Invalid user ID")
    else
      result.continue(user_id)
    end
  }

  # Fetch all data in parallel for better performance
  parallel do
    step ->(result) {
      user_id = result.value
      profile = fetch_user_profile(user_id)
      result.with_context(:profile, profile).continue(user_id)
    }

    step ->(result) {
      user_id = result.value
      orders = fetch_user_orders(user_id)
      result.with_context(:orders, orders).continue(user_id)
    }

    step ->(result) {
      user_id = result.value
      preferences = fetch_user_preferences(user_id)
      result.with_context(:preferences, preferences).continue(user_id)
    }

    step ->(result) {
      user_id = result.value
      analytics = fetch_analytics(user_id)
      result.with_context(:analytics, analytics).continue(user_id)
    }
  end

  # Aggregate all the fetched data
  step ->(result) {
    aggregated = {
      user_id: result.value,
      profile: result.context[:profile],
      orders: result.context[:orders],
      preferences: result.context[:preferences],
      analytics: result.context[:analytics]
    }
    result.continue(aggregated)
  }
end

# Execute the pipeline
puts "Fetching user data (with parallel execution)..."
start_time = Time.now

result = pipeline.call(SimpleFlow::Result.new(42))

elapsed = Time.now - start_time

if result.continue?
  puts "\n✓ Successfully fetched all user data in #{elapsed.round(2)}s"
  puts "\nUser Profile:"
  puts "  Name: #{result.value[:profile][:name]}"
  puts "  Email: #{result.value[:profile][:email]}"
  puts "\nOrders: #{result.value[:orders].length} total"
  puts "  Total Revenue: $#{result.value[:orders].sum { |o| o[:total] }}"
  puts "\nPreferences:"
  puts "  Theme: #{result.value[:preferences][:theme]}"
  puts "  Notifications: #{result.value[:preferences][:notifications]}"
  puts "\nAnalytics:"
  puts "  Page Views: #{result.value[:analytics][:page_views]}"
  puts "  Sessions: #{result.value[:analytics][:sessions]}"
else
  puts "\n✗ Failed to fetch user data"
  puts "Errors: #{result.errors}"
end

puts "\nNote: Without parallel execution, this would take ~0.4s (4 * 0.1s)"
puts "With parallel execution, it takes ~#{elapsed.round(2)}s"
