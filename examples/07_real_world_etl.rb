#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'
require 'json'

# Real-world example: Data ETL (Extract, Transform, Load) pipeline

puts "=" * 60
puts "Real-World Example: Data ETL Pipeline"
puts "=" * 60
puts

# Simulate data sources
class DataSource
  def self.fetch_users_csv
    sleep 0.1
    [
      { id: 1, name: "Alice Johnson", email: "alice@example.com", signup_date: "2023-01-15" },
      { id: 2, name: "Bob Smith", email: "bob@example.com", signup_date: "2023-02-20" },
      { id: 3, name: "Charlie Brown", email: "CHARLIE@EXAMPLE.COM", signup_date: "2023-03-10" }
    ]
  end

  def self.fetch_orders_json
    sleep 0.1
    [
      { order_id: 101, user_id: 1, amount: 150.00, status: "completed" },
      { order_id: 102, user_id: 2, amount: 75.50, status: "pending" },
      { order_id: 103, user_id: 1, amount: 200.00, status: "completed" },
      { order_id: 104, user_id: 3, amount: 50.00, status: "cancelled" }
    ]
  end

  def self.fetch_products_api
    sleep 0.1
    [
      { product_id: "A1", name: "Widget", category: "tools" },
      { product_id: "B2", name: "Gadget", category: "electronics" },
      { product_id: "C3", name: "Doohickey", category: "tools" }
    ]
  end
end

# Build the ETL pipeline
etl_pipeline = SimpleFlow::Pipeline.new do
  # Extract Phase: Load data from multiple sources in parallel
  step :extract_users, ->(result) {
    puts "  📥 Extracting users from CSV..."
    users = DataSource.fetch_users_csv
    result.with_context(:raw_users, users).continue(result.value)
  }, depends_on: []

  step :extract_orders, ->(result) {
    puts "  📥 Extracting orders from JSON..."
    orders = DataSource.fetch_orders_json
    result.with_context(:raw_orders, orders).continue(result.value)
  }, depends_on: []

  step :extract_products, ->(result) {
    puts "  📥 Extracting products from API..."
    products = DataSource.fetch_products_api
    result.with_context(:raw_products, products).continue(result.value)
  }, depends_on: []

  # Transform Phase: Clean and normalize data in parallel
  step :transform_users, ->(result) {
    puts "  🔄 Transforming user data..."
    raw_users = result.context[:raw_users]

    transformed = raw_users.map do |user|
      {
        id: user[:id],
        name: user[:name].downcase.split.map(&:capitalize).join(' '),
        email: user[:email].downcase,
        signup_year: user[:signup_date].split('-').first.to_i,
        created_at: Time.now
      }
    end

    result.with_context(:users, transformed).continue(result.value)
  }, depends_on: [:extract_users]

  step :transform_orders, ->(result) {
    puts "  🔄 Transforming order data..."
    raw_orders = result.context[:raw_orders]

    # Filter out cancelled orders and add computed fields
    transformed = raw_orders
      .reject { |o| o[:status] == "cancelled" }
      .map do |order|
        {
          id: order[:order_id],
          user_id: order[:user_id],
          amount: order[:amount],
          status: order[:status].to_sym,
          tax: (order[:amount] * 0.08).round(2),
          total: (order[:amount] * 1.08).round(2)
        }
      end

    result.with_context(:orders, transformed).continue(result.value)
  }, depends_on: [:extract_orders]

  step :transform_products, ->(result) {
    puts "  🔄 Transforming product data..."
    raw_products = result.context[:raw_products]

    # Normalize and categorize
    transformed = raw_products.map do |product|
      {
        id: product[:product_id],
        name: product[:name],
        category: product[:category].to_sym,
        normalized_name: product[:name].downcase.gsub(/[^a-z0-9]/, '_')
      }
    end

    result.with_context(:products, transformed).continue(result.value)
  }, depends_on: [:extract_products]

  # Aggregate Phase: Join and compute analytics
  step :aggregate_user_stats, ->(result) {
    puts "  📊 Aggregating user statistics..."
    users = result.context[:users]
    orders = result.context[:orders]

    user_stats = users.map do |user|
      user_orders = orders.select { |o| o[:user_id] == user[:id] }
      {
        user_id: user[:id],
        name: user[:name],
        email: user[:email],
        total_orders: user_orders.size,
        total_spent: user_orders.sum { |o| o[:total] },
        avg_order_value: user_orders.size > 0 ? (user_orders.sum { |o| o[:total] } / user_orders.size).round(2) : 0
      }
    end

    result.with_context(:user_stats, user_stats).continue(result.value)
  }, depends_on: [:transform_users, :transform_orders]

  step :aggregate_category_stats, ->(result) {
    puts "  📊 Aggregating category statistics..."
    products = result.context[:products]

    category_stats = products
      .group_by { |p| p[:category] }
      .transform_values { |prods| { count: prods.size, products: prods.map { |p| p[:name] } } }

    result.with_context(:category_stats, category_stats).continue(result.value)
  }, depends_on: [:transform_products]

  # Validation Phase: Check data quality
  step :validate_data, ->(result) {
    puts "  ✅ Validating data quality..."
    users = result.context[:users]
    orders = result.context[:orders]

    issues = []

    # Check for duplicate emails
    emails = users.map { |u| u[:email] }
    duplicates = emails.select { |e| emails.count(e) > 1 }.uniq
    issues << "Duplicate emails found: #{duplicates.join(', ')}" if duplicates.any?

    # Check for orphaned orders
    user_ids = users.map { |u| u[:id] }
    orphaned = orders.reject { |o| user_ids.include?(o[:user_id]) }
    issues << "#{orphaned.size} orphaned orders found" if orphaned.any?

    if issues.any?
      result.with_context(:validation_warnings, issues).continue(result.value)
    else
      result.with_context(:validation_warnings, []).continue(result.value)
    end
  }, depends_on: [:aggregate_user_stats]

  # Load Phase: Prepare final output
  step :prepare_output, ->(result) {
    puts "  💾 Preparing output..."

    output = {
      metadata: {
        processed_at: Time.now,
        pipeline_version: "1.0",
        warnings: result.context[:validation_warnings]
      },
      users: result.context[:users],
      orders: result.context[:orders],
      products: result.context[:products],
      analytics: {
        user_stats: result.context[:user_stats],
        category_stats: result.context[:category_stats],
        summary: {
          total_users: result.context[:users].size,
          total_orders: result.context[:orders].size,
          total_products: result.context[:products].size,
          total_revenue: result.context[:orders].sum { |o| o[:total] }.round(2)
        }
      }
    }

    result.continue(output)
  }, depends_on: [:validate_data, :aggregate_category_stats]
end

puts "\nStarting ETL pipeline..."
puts "=" * 60
puts

start_time = Time.now
result = etl_pipeline.call_parallel(SimpleFlow::Result.new({}))
elapsed = Time.now - start_time

puts "\n" + "=" * 60
if result.continue?
  puts "✅ ETL Pipeline completed successfully!"
  puts "=" * 60

  output = result.value

  puts "\nMetadata:"
  puts "  Processed at: #{output[:metadata][:processed_at]}"
  puts "  Pipeline version: #{output[:metadata][:pipeline_version]}"
  if output[:metadata][:warnings].any?
    puts "  Warnings: #{output[:metadata][:warnings].join('; ')}"
  end

  puts "\nData Summary:"
  puts "  Users processed: #{output[:analytics][:summary][:total_users]}"
  puts "  Orders processed: #{output[:analytics][:summary][:total_orders]}"
  puts "  Products processed: #{output[:analytics][:summary][:total_products]}"
  puts "  Total revenue: $#{output[:analytics][:summary][:total_revenue]}"

  puts "\nUser Statistics:"
  output[:analytics][:user_stats].each do |stat|
    puts "  #{stat[:name]} (#{stat[:email]})"
    puts "    Orders: #{stat[:total_orders]}, Spent: $#{stat[:total_spent]}, Avg: $#{stat[:avg_order_value]}"
  end

  puts "\nCategory Statistics:"
  output[:analytics][:category_stats].each do |category, stats|
    puts "  #{category}: #{stats[:count]} products (#{stats[:products].join(', ')})"
  end

  puts "\nProcessing time: #{(elapsed * 1000).round(2)}ms"

  # Show dependency graph execution
  puts "\nExecution Flow:"
  puts "  Phase 1 (Extract): users, orders, products (parallel)"
  puts "  Phase 2 (Transform): transform_users, transform_orders, transform_products (parallel)"
  puts "  Phase 3 (Aggregate): user_stats, category_stats (parallel after transforms)"
  puts "  Phase 4 (Validate): data validation"
  puts "  Phase 5 (Load): prepare output"

  # Optionally save to file
  if ARGV.include?("--save")
    filename = "etl_output_#{Time.now.to_i}.json"
    File.write(filename, JSON.pretty_generate(output))
    puts "\n✅ Output saved to #{filename}"
  end
else
  puts "❌ ETL Pipeline failed"
  puts "=" * 60
  puts "\nErrors:"
  result.errors.each do |category, messages|
    puts "  #{category}: #{messages.join(', ')}"
  end
end

puts "\n" + "=" * 60
puts "ETL example completed!"
puts "Run with --save flag to save output to JSON file"
puts "=" * 60
