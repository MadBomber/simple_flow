#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 13: Optional Steps in Dynamic DAG
#
# This example demonstrates how to use optional steps that are dynamically
# activated at runtime. Optional steps are declared with `depends_on: :optional`
# and are only executed when explicitly activated via `result.activate(:step_name)`.
#
# Two key patterns are demonstrated:
# 1. Router Pattern - Route execution to different processing paths based on data
# 2. Soft Failure Pattern - Handle errors gracefully with cleanup instead of hard halts

require_relative '../lib/simple_flow'

puts "=" * 70
puts "Optional Steps in Dynamic DAG"
puts "=" * 70

# ============================================================================
# Pattern 1: Router Pattern
# ============================================================================
#
# Use case: Process different types of documents with specialized handlers.
# Each handler is a complete processing path that includes storage.
# The router activates only the appropriate handler based on document type.

puts "\n" + "=" * 70
puts "Pattern 1: Router Pattern"
puts "=" * 70

document_pipeline = SimpleFlow::Pipeline.new do
  # Entry point - determines which processor to activate
  step :analyze_document, ->(result) {
    doc = result.value
    puts "  [analyze] Analyzing document: #{doc[:filename]}"

    case doc[:type]
    when :pdf
      puts "  [analyze] Detected PDF document, routing to PDF processor"
      result.continue(doc).activate(:process_pdf)
    when :image
      puts "  [analyze] Detected image document, routing to image processor"
      result.continue(doc).activate(:process_image)
    when :spreadsheet
      puts "  [analyze] Detected spreadsheet, routing to spreadsheet processor"
      result.continue(doc).activate(:process_spreadsheet)
    else
      puts "  [analyze] Unknown type, routing to generic processor"
      result.continue(doc).activate(:process_generic)
    end
  }, depends_on: :none

  # Optional processors - each is a complete path including storage
  # Only one will be activated per execution
  step :process_pdf, ->(result) {
    doc = result.value
    puts "  [pdf] Extracting text from PDF..."
    puts "  [pdf] Parsing #{doc[:pages] || 1} pages..."
    puts "  [pdf] Storing PDF document in database..."
    result.continue(doc.merge(
      extracted_text: "PDF content from #{doc[:filename]}",
      processor: :pdf,
      stored: true,
      stored_at: Time.now
    ))
  }, depends_on: :optional

  step :process_image, ->(result) {
    doc = result.value
    puts "  [image] Running OCR on image..."
    puts "  [image] Detecting objects in image..."
    puts "  [image] Storing image document in database..."
    result.continue(doc.merge(
      extracted_text: "OCR text from #{doc[:filename]}",
      objects: [:text, :logo],
      processor: :image,
      stored: true,
      stored_at: Time.now
    ))
  }, depends_on: :optional

  step :process_spreadsheet, ->(result) {
    doc = result.value
    puts "  [spreadsheet] Parsing cells and formulas..."
    puts "  [spreadsheet] Extracting #{doc[:rows] || 100} rows..."
    puts "  [spreadsheet] Storing spreadsheet in database..."
    result.continue(doc.merge(
      extracted_data: { rows: doc[:rows] || 100, columns: 5 },
      processor: :spreadsheet,
      stored: true,
      stored_at: Time.now
    ))
  }, depends_on: :optional

  step :process_generic, ->(result) {
    doc = result.value
    puts "  [generic] Applying generic text extraction..."
    puts "  [generic] Storing document in database..."
    result.continue(doc.merge(
      extracted_text: "Generic extraction from #{doc[:filename]}",
      processor: :generic,
      stored: true,
      stored_at: Time.now
    ))
  }, depends_on: :optional
end

# Test with different document types
puts "\nTest 1: Processing a PDF document"
puts "-" * 50
pdf_doc = { filename: "report.pdf", type: :pdf, pages: 42 }
result = document_pipeline.call_parallel(SimpleFlow::Result.new(pdf_doc))
puts "  Result: stored=#{result.value[:stored]}, processor=#{result.value[:processor]}"

puts "\nTest 2: Processing an image"
puts "-" * 50
image_doc = { filename: "scan.jpg", type: :image }
result = document_pipeline.call_parallel(SimpleFlow::Result.new(image_doc))
puts "  Result: stored=#{result.value[:stored]}, processor=#{result.value[:processor]}, objects=#{result.value[:objects]}"

puts "\nTest 3: Processing a spreadsheet"
puts "-" * 50
spreadsheet_doc = { filename: "data.xlsx", type: :spreadsheet, rows: 500 }
result = document_pipeline.call_parallel(SimpleFlow::Result.new(spreadsheet_doc))
puts "  Result: stored=#{result.value[:stored]}, processor=#{result.value[:processor]}"

puts "\nTest 4: Processing an unknown type"
puts "-" * 50
unknown_doc = { filename: "mystery.xyz", type: :unknown }
result = document_pipeline.call_parallel(SimpleFlow::Result.new(unknown_doc))
puts "  Result: stored=#{result.value[:stored]}, processor=#{result.value[:processor]}"

# ============================================================================
# Pattern 2: Soft Failure Pattern
# ============================================================================
#
# Use case: Instead of immediately halting on errors, activate error handling
# and cleanup steps. This allows for graceful degradation, logging, rollback,
# and proper resource cleanup before the pipeline stops.

puts "\n" + "=" * 70
puts "Pattern 2: Soft Failure Pattern"
puts "=" * 70

order_pipeline = SimpleFlow::Pipeline.new do
  step :validate_order, ->(result) {
    order = result.value
    puts "  [validate] Validating order ##{order[:id]}..."

    if order[:items].nil? || order[:items].empty?
      puts "  [validate] ERROR: No items in order!"
      # Instead of halt, activate error handler
      result
        .with_error(:validation, "Order has no items")
        .continue(order.merge(failed_at: :validate_order))
        .activate(:handle_error, :cleanup)
    else
      puts "  [validate] Order validated with #{order[:items].size} items"
      result.continue(order.merge(validated: true))
    end
  }, depends_on: :none

  step :check_inventory, ->(result) {
    order = result.value
    # Skip if we're in error state
    return result if order[:failed_at]

    puts "  [inventory] Checking inventory for #{order[:items].size} items..."

    out_of_stock = order[:items].select { |item| item[:quantity] > 100 }
    if out_of_stock.any?
      puts "  [inventory] ERROR: #{out_of_stock.size} items out of stock!"
      result
        .with_error(:inventory, "Items out of stock: #{out_of_stock.map { |i| i[:name] }.join(', ')}")
        .continue(order.merge(failed_at: :check_inventory, out_of_stock: out_of_stock))
        .activate(:handle_error, :cleanup)
    else
      puts "  [inventory] All items in stock"
      result.continue(order.merge(inventory_checked: true))
    end
  }, depends_on: [:validate_order]

  step :process_payment, ->(result) {
    order = result.value
    # Skip if we're in error state
    return result if order[:failed_at]

    puts "  [payment] Processing payment of $#{order[:total]}..."

    if order[:payment_method] == :invalid
      puts "  [payment] ERROR: Invalid payment method!"
      result
        .with_error(:payment, "Payment declined")
        .continue(order.merge(failed_at: :process_payment))
        .activate(:handle_error, :cleanup)
    else
      puts "  [payment] Payment successful!"
      result.continue(order.merge(paid: true, transaction_id: "TXN-#{rand(10000)}"))
    end
  }, depends_on: [:check_inventory]

  step :fulfill_order, ->(result) {
    order = result.value
    # Skip if we're in error state
    return result if order[:failed_at]

    puts "  [fulfill] Creating shipment..."
    puts "  [fulfill] Order ##{order[:id]} ready for shipping"
    result.continue(order.merge(fulfilled: true, tracking: "SHIP-#{rand(10000)}"))
  }, depends_on: [:process_payment]

  # Error handling step - only runs when activated
  step :handle_error, ->(result) {
    order = result.value
    puts "  [error_handler] Processing error for order ##{order[:id]}..."
    puts "  [error_handler] Failed at step: #{order[:failed_at]}"
    puts "  [error_handler] Errors: #{result.errors}"
    puts "  [error_handler] Logging error to monitoring system..."
    puts "  [error_handler] Sending alert to operations team..."
    result
      .with_context(:error_logged, true)
      .with_context(:alert_sent, true)
      .continue(order.merge(error_handled: true))
  }, depends_on: :optional

  # Cleanup step - only runs when activated, halts after cleanup
  step :cleanup, ->(result) {
    order = result.value
    puts "  [cleanup] Performing cleanup for order ##{order[:id]}..."

    if order[:paid]
      puts "  [cleanup] Refunding payment..."
    end

    if order[:inventory_reserved]
      puts "  [cleanup] Releasing inventory reservation..."
    end

    puts "  [cleanup] Marking order as failed..."
    puts "  [cleanup] Cleanup complete - halting pipeline"

    # After cleanup, we halt to prevent further processing
    result
      .with_context(:cleaned_up, true)
      .continue(order.merge(status: :failed, cleaned_up: true))
      .halt
  }, depends_on: :optional
end

# Test successful order
puts "\nTest 1: Successful order processing"
puts "-" * 50
good_order = {
  id: "ORD-001",
  items: [
    { name: "Widget", quantity: 2, price: 25.00 },
    { name: "Gadget", quantity: 1, price: 49.99 }
  ],
  total: 99.99,
  payment_method: :credit_card
}
result = order_pipeline.call_parallel(SimpleFlow::Result.new(good_order))
puts "  Continue? #{result.continue?}"
puts "  Status: #{result.value[:fulfilled] ? 'Fulfilled' : 'Not fulfilled'}"
puts "  Tracking: #{result.value[:tracking]}"

# Test order with no items (validation failure)
puts "\nTest 2: Order with no items (validation error)"
puts "-" * 50
empty_order = {
  id: "ORD-002",
  items: [],
  total: 0,
  payment_method: :credit_card
}
result = order_pipeline.call_parallel(SimpleFlow::Result.new(empty_order))
puts "  Continue? #{result.continue?}"
puts "  Failed at: #{result.value[:failed_at]}"
puts "  Error handled? #{result.value[:error_handled]}"
puts "  Cleaned up? #{result.value[:cleaned_up]}"
puts "  Errors: #{result.errors}"

# Test order with out-of-stock items
puts "\nTest 3: Order with out-of-stock items"
puts "-" * 50
overstock_order = {
  id: "ORD-003",
  items: [
    { name: "Rare Widget", quantity: 500, price: 100.00 },
    { name: "Common Gadget", quantity: 2, price: 10.00 }
  ],
  total: 50020.00,
  payment_method: :credit_card
}
result = order_pipeline.call_parallel(SimpleFlow::Result.new(overstock_order))
puts "  Continue? #{result.continue?}"
puts "  Failed at: #{result.value[:failed_at]}"
puts "  Out of stock: #{result.value[:out_of_stock]&.map { |i| i[:name] }}"
puts "  Errors: #{result.errors}"

# Test order with payment failure
puts "\nTest 4: Order with invalid payment"
puts "-" * 50
bad_payment_order = {
  id: "ORD-004",
  items: [
    { name: "Widget", quantity: 1, price: 25.00 }
  ],
  total: 25.00,
  payment_method: :invalid
}
result = order_pipeline.call_parallel(SimpleFlow::Result.new(bad_payment_order))
puts "  Continue? #{result.continue?}"
puts "  Failed at: #{result.value[:failed_at]}"
puts "  Errors: #{result.errors}"

# ============================================================================
# Pattern 3: Chained Optional Activation
# ============================================================================
#
# Use case: An optional step can activate other optional steps, creating
# dynamic chains of processing.

puts "\n" + "=" * 70
puts "Pattern 3: Chained Optional Activation"
puts "=" * 70

upgrade_pipeline = SimpleFlow::Pipeline.new do
  step :check_eligibility, ->(result) {
    user = result.value
    puts "  [check] Checking upgrade eligibility for user #{user[:id]}..."

    if user[:tier] == :gold && user[:years] >= 2
      puts "  [check] User eligible for platinum upgrade!"
      result.continue(user).activate(:upgrade_to_platinum)
    elsif user[:tier] == :silver && user[:years] >= 1
      puts "  [check] User eligible for gold upgrade!"
      result.continue(user).activate(:upgrade_to_gold)
    else
      puts "  [check] User not eligible for upgrade"
      result.continue(user.merge(upgrade: :none))
    end
  }, depends_on: :none

  step :upgrade_to_gold, ->(result) {
    user = result.value
    puts "  [gold] Upgrading user to Gold tier..."
    puts "  [gold] Adding Gold benefits..."
    new_user = user.merge(tier: :gold, upgrade: :gold, benefits: [:priority_support, :free_shipping])

    # Gold upgrade also triggers a loyalty bonus
    puts "  [gold] Activating loyalty bonus..."
    result.continue(new_user).activate(:apply_loyalty_bonus)
  }, depends_on: :optional

  step :upgrade_to_platinum, ->(result) {
    user = result.value
    puts "  [platinum] Upgrading user to Platinum tier..."
    puts "  [platinum] Adding Platinum benefits..."
    new_user = user.merge(tier: :platinum, upgrade: :platinum, benefits: [:concierge, :exclusive_events, :free_returns])

    # Platinum upgrade triggers both loyalty bonus AND a special gift
    puts "  [platinum] Activating loyalty bonus and special gift..."
    result.continue(new_user).activate(:apply_loyalty_bonus, :send_special_gift)
  }, depends_on: :optional

  step :apply_loyalty_bonus, ->(result) {
    user = result.value
    bonus_points = user[:years] * 1000
    puts "  [loyalty] Applying #{bonus_points} loyalty bonus points..."
    result.continue(user.merge(bonus_points: bonus_points))
  }, depends_on: :optional

  step :send_special_gift, ->(result) {
    user = result.value
    puts "  [gift] Scheduling special gift delivery..."
    puts "  [gift] Gift: Exclusive member package"
    result.continue(user.merge(gift_scheduled: true))
  }, depends_on: :optional
end

puts "\nTest 1: Silver user eligible for Gold"
puts "-" * 50
silver_user = { id: "U001", tier: :silver, years: 2, name: "Alice" }
result = upgrade_pipeline.call_parallel(SimpleFlow::Result.new(silver_user))
puts "  New tier: #{result.value[:tier]}"
puts "  Benefits: #{result.value[:benefits]}"
puts "  Bonus points: #{result.value[:bonus_points]}"

puts "\nTest 2: Gold user eligible for Platinum"
puts "-" * 50
gold_user = { id: "U002", tier: :gold, years: 3, name: "Bob" }
result = upgrade_pipeline.call_parallel(SimpleFlow::Result.new(gold_user))
puts "  New tier: #{result.value[:tier]}"
puts "  Benefits: #{result.value[:benefits]}"
puts "  Bonus points: #{result.value[:bonus_points]}"
puts "  Gift scheduled: #{result.value[:gift_scheduled]}"

puts "\nTest 3: New user not eligible"
puts "-" * 50
new_user = { id: "U003", tier: :bronze, years: 0, name: "Charlie" }
result = upgrade_pipeline.call_parallel(SimpleFlow::Result.new(new_user))
puts "  Upgrade: #{result.value[:upgrade]}"
puts "  Tier unchanged: #{result.value[:tier]}"

puts "\n" + "=" * 70
puts "Optional steps examples completed!"
puts "=" * 70

puts <<~SUMMARY

  Key Takeaways:

  1. Router Pattern:
     • Use `depends_on: :optional` to declare optional steps
     • Activate specific steps with `result.activate(:step_name)`
     • Each optional step is a complete processing path
     • Great for type-based routing, feature flags, A/B testing

  2. Soft Failure Pattern:
     • Instead of `result.halt`, activate error handlers
     • Error handlers can log, alert, and clean up resources
     • Cleanup step halts after proper teardown
     • Maintains auditability and proper resource management

  3. Chained Optional Activation:
     • Optional steps can activate other optional steps
     • Creates dynamic processing chains based on data
     • Enables complex conditional workflows
     • Each step in the chain can add or modify behavior

  Best Practices:
     • Optional steps work best as "terminal" paths
     • Use the skip pattern (return result if failed) for non-optional steps
     • Activate multiple steps at once: activate(:a, :b, :c)
     • Chain activations for dependent optional behavior

SUMMARY
