#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Example: Complex E-commerce Order Processing Workflow
# This example demonstrates a realistic order processing pipeline with:
# - Multiple parallel steps at different stages
# - Context accumulation across steps
# - Error handling and validation
# - Business logic orchestration

class Order
  attr_accessor :id, :user_id, :items, :total, :payment_method

  def initialize(id:, user_id:, items:, payment_method:)
    @id = id
    @user_id = user_id
    @items = items
    @payment_method = payment_method
    @total = items.sum { |item| item[:price] * item[:quantity] }
  end
end

# Simulate external services
module Services
  def self.validate_user(user_id)
    sleep 0.02
    { valid: true, user: { id: user_id, name: "User #{user_id}", tier: 'gold' } }
  end

  def self.check_inventory(items)
    sleep 0.03
    items.map do |item|
      { item_id: item[:id], available: true, stock: 100 }
    end
  end

  def self.calculate_tax(total, state)
    sleep 0.02
    { tax_rate: 0.08, tax_amount: total * 0.08 }
  end

  def self.calculate_shipping(items, state)
    sleep 0.02
    base = 5.99
    weight_charge = items.sum { |i| i[:quantity] } * 0.5
    { shipping_cost: base + weight_charge, estimated_days: 3 }
  end

  def self.apply_discounts(user, total)
    sleep 0.02
    discount = user[:tier] == 'gold' ? total * 0.1 : 0
    { discount_amount: discount, discount_reason: "#{user[:tier]} member" }
  end

  def self.process_payment(amount, method)
    sleep 0.05
    { success: true, transaction_id: "TXN_#{rand(100_000)}", amount: amount }
  end

  def self.reserve_inventory(items)
    sleep 0.03
    { reserved: true, reservation_id: "RES_#{rand(100_000)}" }
  end

  def self.send_confirmation_email(user_id, order_id)
    sleep 0.02
    { sent: true, email_id: "EMAIL_#{rand(100_000)}" }
  end

  def self.notify_warehouse(order_id, items)
    sleep 0.02
    { notified: true, fulfillment_id: "FUL_#{rand(100_000)}" }
  end

  def self.update_analytics(order_data)
    sleep 0.01
    { recorded: true }
  end
end

# Build the order processing pipeline
def build_order_pipeline
  SimpleFlow::Pipeline.new do
    # Stage 1: Initial Validation
    step ->(result) {
      order = result.value
      puts "Processing order ##{order.id}..."
      result.continue(order)
    }

    # Stage 2: Parallel Validation Checks
    parallel do
      step ->(result) {
        order = result.value
        validation = Services.validate_user(order.user_id)
        validation[:valid] ?
          result.with_context(:user, validation[:user]).continue(order) :
          result.halt(order).with_error(:user, 'Invalid user')
      }

      step ->(result) {
        order = result.value
        inventory = Services.check_inventory(order.items)
        all_available = inventory.all? { |i| i[:available] }
        all_available ?
          result.with_context(:inventory, inventory).continue(order) :
          result.halt(order).with_error(:inventory, 'Items not available')
      }
    end

    # Stage 3: Parallel Price Calculations
    parallel do
      step ->(result) {
        order = result.value
        tax = Services.calculate_tax(order.total, 'CA')
        result.with_context(:tax, tax).continue(order)
      }

      step ->(result) {
        order = result.value
        shipping = Services.calculate_shipping(order.items, 'CA')
        result.with_context(:shipping, shipping).continue(order)
      }

      step ->(result) {
        order = result.value
        user = result.context[:user]
        discount = Services.apply_discounts(user, order.total)
        result.with_context(:discount, discount).continue(order)
      }
    end

    # Stage 4: Calculate Final Amount
    step ->(result) {
      order = result.value
      subtotal = order.total
      tax = result.context[:tax][:tax_amount]
      shipping = result.context[:shipping][:shipping_cost]
      discount = result.context[:discount][:discount_amount]

      final_amount = subtotal + tax + shipping - discount

      puts "\nOrder Summary:"
      puts "  Subtotal:  $#{subtotal.round(2)}"
      puts "  Tax:       $#{tax.round(2)}"
      puts "  Shipping:  $#{shipping.round(2)}"
      puts "  Discount: -$#{discount.round(2)}"
      puts "  " + '-' * 30
      puts "  Total:     $#{final_amount.round(2)}"

      result.with_context(:final_amount, final_amount).continue(order)
    }

    # Stage 5: Process Payment and Reserve Inventory in Parallel
    parallel do
      step ->(result) {
        order = result.value
        amount = result.context[:final_amount]
        payment = Services.process_payment(amount, order.payment_method)
        payment[:success] ?
          result.with_context(:payment, payment).continue(order) :
          result.halt(order).with_error(:payment, 'Payment failed')
      }

      step ->(result) {
        order = result.value
        reservation = Services.reserve_inventory(order.items)
        result.with_context(:reservation, reservation).continue(order)
      }
    end

    # Stage 6: Post-processing in Parallel
    parallel do
      step ->(result) {
        order = result.value
        email = Services.send_confirmation_email(order.user_id, order.id)
        result.with_context(:email, email).continue(order)
      }

      step ->(result) {
        order = result.value
        warehouse = Services.notify_warehouse(order.id, order.items)
        result.with_context(:warehouse, warehouse).continue(order)
      }

      step ->(result) {
        order = result.value
        analytics = Services.update_analytics(result.context)
        result.with_context(:analytics, analytics).continue(order)
      }
    end

    # Final step: Build confirmation
    step ->(result) {
      order = result.value
      confirmation = {
        order_id: order.id,
        status: 'confirmed',
        transaction_id: result.context[:payment][:transaction_id],
        fulfillment_id: result.context[:warehouse][:fulfillment_id],
        estimated_delivery: result.context[:shipping][:estimated_days],
        email_sent: result.context[:email][:sent]
      }

      puts "\n✓ Order ##{order.id} processed successfully!"
      puts "  Transaction ID: #{confirmation[:transaction_id]}"
      puts "  Fulfillment ID: #{confirmation[:fulfillment_id]}"
      puts "  Estimated delivery: #{confirmation[:estimated_delivery]} days"

      result.continue(confirmation)
    }
  end
end

# Run the example
puts '=' * 70
puts 'SimpleFlow: Complex E-commerce Order Processing Workflow'
puts '=' * 70
puts

order = Order.new(
  id: 12345,
  user_id: 789,
  items: [
    { id: 1, name: 'Widget', price: 29.99, quantity: 2 },
    { id: 2, name: 'Gadget', price: 49.99, quantity: 1 }
  ],
  payment_method: 'credit_card'
)

puts "Initial Order:"
puts "  Order ID: #{order.id}"
puts "  User ID: #{order.user_id}"
puts "  Items: #{order.items.length}"
puts "  Subtotal: $#{order.total.round(2)}"
puts

start_time = Time.now
pipeline = build_order_pipeline
result = pipeline.call(SimpleFlow::Result.new(order))
elapsed = Time.now - start_time

if result.continue?
  puts "\n" + '=' * 70
  puts "Pipeline completed successfully in #{elapsed.round(2)}s"
  puts '=' * 70
  puts "\nFinal confirmation:"
  puts result.value.inspect
else
  puts "\n✗ Order processing failed"
  puts "Errors:"
  result.errors.each { |key, msgs| puts "  #{key}: #{msgs.join(', ')}" }
end

puts "\n" + '=' * 70
puts "This workflow demonstrates:"
puts "  - 6 stages of processing"
puts "  - 4 parallel execution blocks"
puts "  - Context accumulation across 15+ steps"
puts "  - Error handling and validation"
puts "  - Real-world business logic orchestration"
puts '=' * 70
