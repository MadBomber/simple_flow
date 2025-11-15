# Complex Workflows Guide

This guide demonstrates how to build sophisticated, real-world workflows using SimpleFlow's advanced features.

## E-Commerce Order Processing

Complete order processing pipeline with validation, inventory, payment, and notifications:

```ruby
class OrderProcessor
  def self.build
    SimpleFlow::Pipeline.new do
      # Step 1: Validate order
      step :validate_order, ->(result) {
        order = result.value
        errors = []

        errors << "Missing email" unless order[:customer][:email]
        errors << "No items" if order[:items].empty?
        errors << "Missing payment" unless order[:payment][:card_token]

        if errors.any?
          result.halt.with_error(:validation, errors.join(", "))
        else
          result.with_context(:validated_at, Time.now).continue(order)
        end
      }, depends_on: []

      # Steps 2-3: Parallel checks
      step :check_inventory, ->(result) {
        order = result.value
        inventory_results = order[:items].map do |item|
          InventoryService.check_availability(item[:product_id])
        end

        if inventory_results.all? { |r| r[:available] }
          result.with_context(:inventory_check, inventory_results).continue(order)
        else
          result.halt.with_error(:inventory, "Items out of stock")
        end
      }, depends_on: [:validate_order]

      step :calculate_shipping, ->(result) {
        order = result.value
        shipping = ShippingService.calculate(
          order[:shipping_address],
          order[:items]
        )
        result.with_context(:shipping, shipping).continue(order)
      }, depends_on: [:validate_order]

      # Step 4: Calculate totals
      step :calculate_totals, ->(result) {
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
        order = result.value
        total = result.context[:total]

        payment_result = PaymentService.process(
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
        order = result.value
        reservation = InventoryService.reserve(order[:items])
        result.with_context(:reservation, reservation).continue(order)
      }, depends_on: [:process_payment]

      # Step 7: Create shipment
      step :create_shipment, ->(result) {
        order = result.value
        shipment = ShippingService.create_shipment(
          order[:order_id],
          order[:shipping_address]
        )
        result.with_context(:shipment, shipment).continue(order)
      }, depends_on: [:reserve_inventory]

      # Steps 8-9: Parallel notifications
      step :send_email, ->(result) {
        order = result.value
        NotificationService.send_email(
          order[:customer][:email],
          "Order Confirmed",
          order_confirmation_body(order, result.context)
        )
        result.continue(order)
      }, depends_on: [:create_shipment]

      step :send_sms, ->(result) {
        order = result.value
        if order[:customer][:phone]
          NotificationService.send_sms(
            order[:customer][:phone],
            "Order confirmed! Tracking: #{result.context[:shipment][:tracking]}"
          )
        end
        result.continue(order)
      }, depends_on: [:create_shipment]

      # Step 10: Finalize
      step :finalize_order, ->(result) {
        order = result.value
        final_order = {
          order_id: order[:order_id],
          status: :confirmed,
          total: result.context[:total],
          payment_transaction: result.context[:payment][:transaction_id],
          tracking_number: result.context[:shipment][:tracking_number]
        }
        result.continue(final_order)
      }, depends_on: [:send_email, :send_sms]
    end
  end
end

# Usage
result = OrderProcessor.build.call_parallel(
  SimpleFlow::Result.new(order_data)
)

if result.continue?
  puts "Order #{result.value[:order_id]} processed successfully"
else
  puts "Order failed: #{result.errors}"
end
```

## ETL Data Pipeline

Extract, Transform, Load pipeline with validation and error handling:

```ruby
class ETLPipeline
  def self.build
    SimpleFlow::Pipeline.new do
      # Extract phase - parallel loading
      step :extract_users, ->(result) {
        users = DataSource.fetch_users_csv
        result.with_context(:raw_users, users).continue(result.value)
      }, depends_on: []

      step :extract_orders, ->(result) {
        orders = DataSource.fetch_orders_json
        result.with_context(:raw_orders, orders).continue(result.value)
      }, depends_on: []

      step :extract_products, ->(result) {
        products = DataSource.fetch_products_api
        result.with_context(:raw_products, products).continue(result.value)
      }, depends_on: []

      # Transform phase - parallel transformations
      step :transform_users, ->(result) {
        users = result.context[:raw_users].map do |user|
          {
            id: user[:id],
            name: user[:name].downcase.split.map(&:capitalize).join(' '),
            email: user[:email].downcase,
            signup_year: user[:signup_date].split('-').first.to_i
          }
        end
        result.with_context(:users, users).continue(result.value)
      }, depends_on: [:extract_users]

      step :transform_orders, ->(result) {
        orders = result.context[:raw_orders]
          .reject { |o| o[:status] == "cancelled" }
          .map do |order|
            {
              id: order[:order_id],
              user_id: order[:user_id],
              amount: order[:amount],
              tax: (order[:amount] * 0.08).round(2),
              total: (order[:amount] * 1.08).round(2)
            }
          end
        result.with_context(:orders, orders).continue(result.value)
      }, depends_on: [:extract_orders]

      step :transform_products, ->(result) {
        products = result.context[:raw_products].map do |product|
          {
            id: product[:product_id],
            name: product[:name],
            category: product[:category].to_sym
          }
        end
        result.with_context(:products, products).continue(result.value)
      }, depends_on: [:extract_products]

      # Aggregate phase
      step :aggregate_stats, ->(result) {
        users = result.context[:users]
        orders = result.context[:orders]

        stats = users.map do |user|
          user_orders = orders.select { |o| o[:user_id] == user[:id] }
          {
            user_id: user[:id],
            name: user[:name],
            total_orders: user_orders.size,
            total_spent: user_orders.sum { |o| o[:total] },
            avg_order: user_orders.empty? ? 0 : user_orders.sum { |o| o[:total] } / user_orders.size
          }
        end

        result.with_context(:user_stats, stats).continue(result.value)
      }, depends_on: [:transform_users, :transform_orders]

      # Validation phase
      step :validate_data, ->(result) {
        users = result.context[:users]
        orders = result.context[:orders]

        issues = []

        # Check for orphaned orders
        user_ids = users.map { |u| u[:id] }
        orphaned = orders.reject { |o| user_ids.include?(o[:user_id]) }
        issues << "#{orphaned.size} orphaned orders" if orphaned.any?

        result.with_context(:validation_warnings, issues).continue(result.value)
      }, depends_on: [:aggregate_stats]

      # Load phase
      step :prepare_output, ->(result) {
        output = {
          metadata: {
            processed_at: Time.now,
            warnings: result.context[:validation_warnings]
          },
          analytics: {
            user_stats: result.context[:user_stats],
            summary: {
              total_users: result.context[:users].size,
              total_orders: result.context[:orders].size,
              total_revenue: result.context[:orders].sum { |o| o[:total] }
            }
          }
        }
        result.continue(output)
      }, depends_on: [:validate_data]
    end
  end
end
```

## Multi-Service Integration

Orchestrating multiple external services:

```ruby
class UserOnboarding
  def self.build
    SimpleFlow::Pipeline.new do
      # Validate user data
      step :validate_user, ->(result) {
        user_data = result.value
        validator = UserValidator.new(user_data)

        if validator.valid?
          result.continue(user_data)
        else
          result.halt.with_error(:validation, validator.errors.join(", "))
        end
      }, depends_on: []

      # Parallel service calls
      step :create_auth_account, ->(result) {
        user = result.value
        auth_account = AuthService.create_account(
          email: user[:email],
          password: user[:password]
        )
        result.with_context(:auth_id, auth_account[:id]).continue(user)
      }, depends_on: [:validate_user]

      step :create_profile, ->(result) {
        user = result.value
        profile = ProfileService.create(
          name: user[:name],
          bio: user[:bio]
        )
        result.with_context(:profile_id, profile[:id]).continue(user)
      }, depends_on: [:validate_user]

      step :setup_preferences, ->(result) {
        user = result.value
        prefs = PreferenceService.initialize_defaults(user[:preferences] || {})
        result.with_context(:preferences_id, prefs[:id]).continue(user)
      }, depends_on: [:validate_user]

      # Link accounts
      step :link_accounts, ->(result) {
        user_record = User.create!(
          email: result.value[:email],
          auth_id: result.context[:auth_id],
          profile_id: result.context[:profile_id],
          preferences_id: result.context[:preferences_id]
        )
        result.with_context(:user, user_record).continue(user_record)
      }, depends_on: [:create_auth_account, :create_profile, :setup_preferences]

      # Parallel post-creation tasks
      step :send_welcome_email, ->(result) {
        user = result.context[:user]
        EmailService.send_welcome(user.email)
        result.continue(result.value)
      }, depends_on: [:link_accounts]

      step :trigger_analytics, ->(result) {
        user = result.context[:user]
        AnalyticsService.track_signup(user)
        result.continue(result.value)
      }, depends_on: [:link_accounts]

      step :create_trial_subscription, ->(result) {
        user = result.context[:user]
        subscription = BillingService.create_trial(user)
        result.with_context(:subscription, subscription).continue(result.value)
      }, depends_on: [:link_accounts]

      # Finalize
      step :finalize, ->(result) {
        {
          user_id: result.context[:user].id,
          subscription_id: result.context[:subscription][:id],
          onboarded_at: Time.now
        }
      }, depends_on: [:send_welcome_email, :trigger_analytics, :create_trial_subscription]
    end
  end
end
```

## Error Recovery Workflow

Advanced error handling with fallbacks and retries:

```ruby
class ResilientDataFetcher
  def self.build
    SimpleFlow::Pipeline.new do
      # Try primary data source
      step :fetch_primary, ->(result) {
        begin
          data = PrimaryAPI.fetch(result.value)
          result.with_context(:source, :primary).continue(data)
        rescue PrimaryAPI::Error => e
          result
            .with_context(:primary_error, e.message)
            .continue(result.value)
        end
      }, depends_on: []

      # Try secondary if primary failed
      step :fetch_secondary, ->(result) {
        # Skip if primary succeeded
        if result.context[:source] == :primary
          return result.continue(result.value)
        end

        begin
          data = SecondaryAPI.fetch(result.value)
          result.with_context(:source, :secondary).continue(data)
        rescue SecondaryAPI::Error => e
          result
            .with_context(:secondary_error, e.message)
            .continue(result.value)
        end
      }, depends_on: [:fetch_primary]

      # Fallback to cache
      step :fetch_cache, ->(result) {
        # Skip if we have data
        if result.context[:source]
          return result.continue(result.value)
        end

        cached = CacheService.get(result.value)
        if cached
          result.with_context(:source, :cache).continue(cached)
        else
          result.halt.with_error(
            :data_unavailable,
            "All data sources failed: #{[
              result.context[:primary_error],
              result.context[:secondary_error]
            ].compact.join(', ')}"
          )
        end
      }, depends_on: [:fetch_secondary]

      # Update cache if we fetched from API
      step :update_cache, ->(result) {
        if [:primary, :secondary].include?(result.context[:source])
          CacheService.set(result.value, result.value)
        end
        result.continue(result.value)
      }, depends_on: [:fetch_cache]
    end
  end
end
```

## For complete examples, see:

- `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/examples/06_real_world_ecommerce.rb` - Full e-commerce workflow
- `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/examples/07_real_world_etl.rb` - Complete ETL pipeline

## Related Documentation

- [Error Handling](error-handling.md) - Error handling strategies
- [Validation Patterns](validation-patterns.md) - Data validation
- [Data Fetching](data-fetching.md) - Fetching external data
- [Parallel Steps](../concurrent/parallel-steps.md) - Concurrent execution
