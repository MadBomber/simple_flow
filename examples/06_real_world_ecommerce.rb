#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'
require 'json'
require 'timecop'
Timecop.travel(Time.local(2001, 9, 11, 7, 0, 0))

# Real-world example: E-commerce order processing pipeline

puts "=" * 60
puts "Real-World Example: E-commerce Order Processing"
puts "=" * 60
puts

# Simulate external services
class InventoryService
  def self.check_availability(product_id)
    sleep 0.05  # Simulate API call
    { product_id: product_id, available: true, quantity: 100 }
  end

  def self.reserve_items(items)
    sleep 0.05
    { reservation_id: "RES-#{rand(10000)}", items: items }
  end
end

class PaymentService
  def self.process_payment(amount, card_token)
    sleep 0.1  # Simulate payment processing
    if card_token.start_with?("tok_")
      { transaction_id: "TXN-#{rand(10000)}", status: :success, amount: amount }
    else
      { status: :failed, reason: "Invalid card token" }
    end
  end
end

class ShippingService
  def self.calculate_shipping(address, items)
    sleep 0.05
    { cost: 10.00, estimated_days: 3 }
  end

  def self.create_shipment(order_id, address)
    sleep 0.05
    { tracking_number: "TRACK-#{rand(10000)}", carrier: "FastShip" }
  end
end

class NotificationService
  def self.send_email(to, subject, body)
    sleep 0.02
    puts "    📧 Email sent to #{to}: #{subject}"
    { sent: true, message_id: "MSG-#{rand(10000)}" }
  end

  def self.send_sms(phone, message)
    sleep 0.02
    puts "    📱 SMS sent to #{phone}: #{message}"
    { sent: true }
  end
end

# Build the order processing pipeline
order_pipeline = SimpleFlow::Pipeline.new do
  # Step 1: Validate order
  step :validate_order, ->(result) {
    puts "  ✓ Validating order..."
    order = result.value

    # Check required fields
    errors = []
    errors << "Missing customer email" unless order[:customer][:email]
    errors << "No items in order" if order[:items].empty?
    errors << "Missing payment method" unless order[:payment][:card_token]

    if errors.any?
      return result.halt.with_error(:validation, errors.join(", "))
    end

    result.with_context(:validated_at, Time.now).continue(order)
  }, depends_on: :none

  # Step 2 & 3: Run in parallel - check inventory and calculate shipping
  step :check_inventory, ->(result) {
    puts "  ✓ Checking inventory..."
    order = result.value
    inventory_results = order[:items].map do |item|
      InventoryService.check_availability(item[:product_id])
    end

    if inventory_results.all? { |r| r[:available] }
      result.with_context(:inventory_check, inventory_results).continue(order)
    else
      result.halt.with_error(:inventory, "Some items are out of stock")
    end
  }, depends_on: [:validate_order]

  step :calculate_shipping, ->(result) {
    puts "  ✓ Calculating shipping..."
    order = result.value
    shipping = ShippingService.calculate_shipping(
      order[:shipping_address],
      order[:items]
    )
    result.with_context(:shipping, shipping).continue(order)
  }, depends_on: [:validate_order]

  # Step 4: Calculate totals (waits for inventory and shipping)
  step :calculate_totals, ->(result) {
    puts "  ✓ Calculating totals..."
    order = result.value
    shipping = result.context[:shipping]

    subtotal = order[:items].sum { |item| item[:price] * item[:quantity] }
    tax = subtotal * 0.08
    total = subtotal + tax + shipping[:cost]

    result
      .with_context(:subtotal, subtotal)
      .with_context(:tax, tax)
      .with_context(:total, total)
      .continue(order)
  }, depends_on: [:check_inventory, :calculate_shipping]

  # Step 5: Process payment
  step :process_payment, ->(result) {
    puts "  ✓ Processing payment..."
    order = result.value
    total = result.context[:total]

    payment_result = PaymentService.process_payment(
      total,
      order[:payment][:card_token]
    )

    if payment_result[:status] == :success
      result.with_context(:payment, payment_result).continue(order)
    else
      result.halt.with_error(:payment, payment_result[:reason])
    end
  }, depends_on: [:calculate_totals]

  # Step 6: Reserve inventory
  step :reserve_inventory, ->(result) {
    puts "  ✓ Reserving inventory..."
    order = result.value
    reservation = InventoryService.reserve_items(order[:items])
    result.with_context(:reservation, reservation).continue(order)
  }, depends_on: [:process_payment]

  # Step 7: Create shipment
  step :create_shipment, ->(result) {
    puts "  ✓ Creating shipment..."
    order = result.value
    shipment = ShippingService.create_shipment(
      order[:order_id],
      order[:shipping_address]
    )
    result.with_context(:shipment, shipment).continue(order)
  }, depends_on: [:reserve_inventory]

  # Step 8 & 9: Send notifications in parallel
  step :send_email_confirmation, ->(result) {
    puts "  ✓ Sending email confirmation..."
    order = result.value
    total = result.context[:total]
    tracking = result.context[:shipment][:tracking_number]

    NotificationService.send_email(
      order[:customer][:email],
      "Order Confirmed",
      "Your order ##{order[:order_id]} for $#{total.round(2)} has been confirmed. Tracking: #{tracking}"
    )

    result.continue(order)
  }, depends_on: [:create_shipment]

  step :send_sms_confirmation, ->(result) {
    puts "  ✓ Sending SMS confirmation..."
    order = result.value
    tracking = result.context[:shipment][:tracking_number]

    if order[:customer][:phone]
      NotificationService.send_sms(
        order[:customer][:phone],
        "Order confirmed! Tracking: #{tracking}"
      )
    end

    result.continue(order)
  }, depends_on: [:create_shipment]

  # Step 10: Finalize order
  step :finalize_order, ->(result) {
    puts "  ✓ Finalizing order..."
    order = result.value

    final_order = {
      order_id: order[:order_id],
      status: :confirmed,
      total: result.context[:total],
      payment_transaction: result.context[:payment][:transaction_id],
      tracking_number: result.context[:shipment][:tracking_number],
      estimated_delivery_days: result.context[:shipping][:estimated_days]
    }

    result.continue(final_order)
  }, depends_on: [:send_email_confirmation, :send_sms_confirmation]
end

# Example order data
order = {
  order_id: "ORD-#{rand(10000)}",
  customer: {
    email: "customer@example.com",
    phone: "+1-555-0123"
  },
  items: [
    { product_id: 101, name: "Widget", price: 29.99, quantity: 2 },
    { product_id: 102, name: "Gadget", price: 49.99, quantity: 1 }
  ],
  shipping_address: {
    street: "123 Main St",
    city: "Springfield",
    state: "IL",
    zip: "62701"
  },
  payment: {
    card_token: "tok_valid_card_123"
  }
}

puts "\nProcessing order: #{order[:order_id]}"
puts "Items: #{order[:items].size} items totaling $#{order[:items].sum { |i| i[:price] * i[:quantity] }}"
puts

start_time = Time.now
result = order_pipeline.call_parallel(SimpleFlow::Result.new(order))
elapsed = Time.now - start_time

puts "\n" + "=" * 60
if result.continue?
  puts "✅ Order processed successfully!"
  puts "=" * 60
  puts "\nOrder Details:"
  puts "  Order ID: #{result.value[:order_id]}"
  puts "  Status: #{result.value[:status]}"
  puts "  Total: $#{result.value[:total].round(2)}"
  puts "  Transaction: #{result.value[:payment_transaction]}"
  puts "  Tracking: #{result.value[:tracking_number]}"
  puts "  Estimated Delivery: #{result.value[:estimated_delivery_days]} days"
  puts "\nProcessing time: #{(elapsed * 1000).round(2)}ms"
else
  puts "❌ Order processing failed"
  puts "=" * 60
  puts "\nErrors:"
  result.errors.each do |category, messages|
    puts "  #{category}: #{messages.join(', ')}"
  end
end

# Test with invalid order
puts "\n\n" + "=" * 60
puts "Testing with invalid order (missing payment)..."
puts "=" * 60
puts

invalid_order = order.dup
invalid_order[:payment][:card_token] = "invalid_token"

result2 = order_pipeline.call_parallel(SimpleFlow::Result.new(invalid_order))

if result2.continue?
  puts "✅ Order processed"
else
  puts "❌ Order failed (as expected)"
  puts "\nErrors:"
  result2.errors.each do |category, messages|
    puts "  #{category}: #{messages.join(', ')}"
  end
end

puts "\n" + "=" * 60
puts "E-commerce example completed!"
puts "=" * 60
