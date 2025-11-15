# Error Handling Guide

SimpleFlow provides flexible mechanisms for handling errors, validating data, and controlling pipeline flow. This guide covers comprehensive error handling strategies.

## Core Concepts

### The Result Object

Every step receives and returns a `Result` object with three key components:

- **value**: The data being processed
- **context**: Metadata and contextual information
- **errors**: Accumulated error messages organized by category

### Flow Control

Steps control execution flow using two methods:

- `continue(new_value)`: Proceed to next step with updated value
- `halt(new_value = nil)`: Stop pipeline execution

## Basic Error Handling

### Halting on Validation Failure

The simplest error handling pattern is to halt immediately when validation fails:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    age = result.value

    if age < 18
      result.halt.with_error(:validation, "Must be 18 or older")
    else
      result.continue(age)
    end
  }

  step ->(result) {
    # This only runs if age >= 18
    result.continue("Approved for age #{result.value}")
  }
end

result = pipeline.call(SimpleFlow::Result.new(15))
result.continue?  # => false
result.errors     # => {:validation => ["Must be 18 or older"]}
```

### Checking Continue Status

Always check `continue?` to determine if pipeline completed successfully:

```ruby
result = pipeline.call(initial_data)

if result.continue?
  puts "Success: #{result.value}"
else
  puts "Failed with errors: #{result.errors}"
end
```

## Error Accumulation

### Collecting Multiple Errors

Instead of halting at the first error, collect all validation errors:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    password = result.value

    result = if password.length < 8
      result.with_error(:password, "Must be at least 8 characters")
    else
      result
    end

    result = unless password =~ /[A-Z]/
      result.with_error(:password, "Must contain uppercase letters")
    else
      result
    end

    result = unless password =~ /[0-9]/
      result.with_error(:password, "Must contain numbers")
    else
      result
    end

    result.continue(password)
  }

  step ->(result) {
    # Check if any errors were accumulated
    if result.errors.any?
      result.halt.with_error(:validation, "Password requirements not met")
    else
      result.continue(result.value)
    end
  }

  step ->(result) {
    # Only executes if no validation errors
    result.continue("Password accepted")
  }
end

result = pipeline.call(SimpleFlow::Result.new("weak"))
result.errors
# => {
#      :password => [
#        "Must be at least 8 characters",
#        "Must contain uppercase letters",
#        "Must contain numbers"
#      ],
#      :validation => ["Password requirements not met"]
#    }
```

### Parallel Validation

Use parallel execution to run multiple validations concurrently:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Validate multiple fields in parallel
  step :validate_email, ->(result) {
    unless valid_email?(result.value[:email])
      result.with_error(:email, "Invalid email format")
    end
    result.continue(result.value)
  }, depends_on: []

  step :validate_phone, ->(result) {
    unless valid_phone?(result.value[:phone])
      result.with_error(:phone, "Invalid phone format")
    end
    result.continue(result.value)
  }, depends_on: []

  step :validate_age, ->(result) {
    if result.value[:age] < 18
      result.with_error(:age, "Must be 18 or older")
    end
    result.continue(result.value)
  }, depends_on: []

  # Check all validation results
  step :verify_validations, ->(result) {
    if result.errors.any?
      result.halt(result.value)
    else
      result.continue(result.value)
    end
  }, depends_on: [:validate_email, :validate_phone, :validate_age]

  # Only runs if all validations pass
  step :create_account, ->(result) {
    result.continue("Account created successfully")
  }, depends_on: [:verify_validations]
end
```

## Error Categories

### Organizing Errors by Type

Use symbols to categorize errors for better organization:

```ruby
step :process_order, ->(result) {
  order = result.value

  # Business logic errors
  if order[:total] > 10000
    return result.halt.with_error(:business_rule, "Order exceeds maximum amount")
  end

  # Inventory errors
  unless inventory_available?(order[:items])
    return result.halt.with_error(:inventory, "Items out of stock")
  end

  # Payment errors
  unless valid_payment?(order[:payment])
    return result.halt.with_error(:payment, "Payment method declined")
  end

  result.continue(order)
}

# Access errors by category
result = pipeline.call(order_data)
result.errors[:business_rule]  # => ["Order exceeds maximum amount"]
result.errors[:inventory]      # => nil
result.errors[:payment]        # => nil
```

### Multiple Errors Per Category

The `with_error` method appends to existing errors in a category:

```ruby
step :validate_fields, ->(result) {
  data = result.value
  result_obj = result

  if data[:name].nil?
    result_obj = result_obj.with_error(:required, "Name is required")
  end

  if data[:email].nil?
    result_obj = result_obj.with_error(:required, "Email is required")
  end

  if data[:phone].nil?
    result_obj = result_obj.with_error(:required, "Phone is required")
  end

  result_obj.continue(data)
}

# result.errors[:required] => ["Name is required", "Email is required", "Phone is required"]
```

## Exception Handling

### Rescuing Exceptions

Wrap external calls in exception handlers:

```ruby
step :fetch_from_api, ->(result) {
  begin
    response = HTTP.get("https://api.example.com/data")
    data = JSON.parse(response.body)
    result.with_context(:api_data, data).continue(result.value)
  rescue HTTP::Error => e
    result.halt.with_error(:network, "API request failed: #{e.message}")
  rescue JSON::ParserError => e
    result.halt.with_error(:parse, "Invalid JSON response: #{e.message}")
  rescue StandardError => e
    result.halt.with_error(:unknown, "Unexpected error: #{e.message}")
  end
}
```

### Retry Logic with Middleware

Implement retry logic using custom middleware:

```ruby
class RetryMiddleware
  def initialize(callable, max_retries: 3, retry_on: [StandardError])
    @callable = callable
    @max_retries = max_retries
    @retry_on = Array(retry_on)
  end

  def call(result)
    attempts = 0

    begin
      attempts += 1
      @callable.call(result)
    rescue *@retry_on => e
      if attempts < @max_retries
        sleep(attempts ** 2)  # Exponential backoff
        retry
      else
        result.halt.with_error(
          :retry_exhausted,
          "Failed after #{@max_retries} attempts: #{e.message}"
        )
      end
    end
  end
end

pipeline = SimpleFlow::Pipeline.new do
  use_middleware RetryMiddleware, max_retries: 3, retry_on: [Net::HTTPError, Timeout::Error]

  step ->(result) {
    # This step will be retried up to 3 times on network errors
    data = fetch_from_unreliable_api(result.value)
    result.continue(data)
  }
end
```

## Conditional Processing

### Early Exit on Errors

Check for errors and exit early if found:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :load_data, ->(result) {
    begin
      data = load_file(result.value)
      result.continue(data)
    rescue Errno::ENOENT
      result.halt.with_error(:file, "File not found")
    end
  }

  step :validate_data, ->(result) {
    # Only runs if load_data succeeded
    if invalid?(result.value)
      result.halt.with_error(:validation, "Invalid data format")
    else
      result.continue(result.value)
    end
  }

  step :process_data, ->(result) {
    # Only runs if both previous steps succeeded
    processed = transform(result.value)
    result.continue(processed)
  }
end
```

### Conditional Flow Based on Context

Use context to make decisions about flow:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :check_user_role, ->(result) {
    user = result.value
    result.with_context(:role, user[:role]).continue(user)
  }

  step :authorize_action, ->(result) {
    case result.context[:role]
    when :admin
      result.with_context(:authorized, true).continue(result.value)
    when :user
      if can_access?(result.value)
        result.with_context(:authorized, true).continue(result.value)
      else
        result.halt.with_error(:auth, "Insufficient permissions")
      end
    else
      result.halt.with_error(:auth, "Unknown role")
    end
  }

  step :perform_action, ->(result) {
    # Only executes if authorized
    result.continue("Action completed")
  }
end
```

## Error Recovery

### Fallback Values

Provide fallback values when operations fail:

```ruby
step :fetch_with_fallback, ->(result) {
  begin
    data = fetch_from_primary_api(result.value)
    result.with_context(:source, :primary).continue(data)
  rescue API::Error
    # Try secondary source
    begin
      data = fetch_from_secondary_api(result.value)
      result.with_context(:source, :secondary).continue(data)
    rescue API::Error
      # Use cached data as last resort
      cached_data = fetch_from_cache(result.value)
      if cached_data
        result.with_context(:source, :cache).continue(cached_data)
      else
        result.halt.with_error(:data, "All data sources unavailable")
      end
    end
  end
}
```

### Partial Success Handling

Continue processing even if some operations fail:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :batch_process, ->(result) {
    items = result.value
    successful = []
    failed = []

    items.each do |item|
      begin
        processed = process_item(item)
        successful << processed
      rescue ProcessingError => e
        failed << { item: item, error: e.message }
      end
    end

    result_obj = result.continue(successful)

    if failed.any?
      result_obj = result_obj.with_context(:failed_items, failed)
      result_obj = result_obj.with_error(:partial_failure, "#{failed.size} items failed to process")
    end

    result_obj
  }

  step :handle_results, ->(result) {
    if result.context[:failed_items]
      # Log failures but continue
      log_failures(result.context[:failed_items])
    end

    result.continue("Processed #{result.value.size} items")
  }
end
```

## Debugging Halted Pipelines

### Using StepTracker

SimpleFlow's `StepTracker` adds context about where execution halted:

```ruby
require 'simple_flow/step_tracker'

step_a = SimpleFlow::StepTracker.new(->(result) {
  result.continue("Step A done")
})

step_b = SimpleFlow::StepTracker.new(->(result) {
  result.halt.with_error(:failure, "Step B failed")
})

step_c = SimpleFlow::StepTracker.new(->(result) {
  result.continue("Step C done")
})

pipeline = SimpleFlow::Pipeline.new do
  step step_a
  step step_b
  step step_c
end

result = pipeline.call(SimpleFlow::Result.new(nil))
result.context[:halted_step]  # => The step_b lambda
```

### Adding Debug Context

Add helpful debugging information to context:

```ruby
step :debug_step, ->(result) {
  result
    .with_context(:step_name, "debug_step")
    .with_context(:timestamp, Time.now)
    .with_context(:input_size, result.value.size)
    .continue(result.value)
}
```

## Validation Patterns

### Schema Validation

Validate data structure before processing:

```ruby
step :validate_schema, ->(result) {
  data = result.value
  required_fields = [:name, :email, :age]

  missing = required_fields.reject { |field| data.key?(field) }

  if missing.any?
    result.halt.with_error(
      :schema,
      "Missing required fields: #{missing.join(', ')}"
    )
  else
    result.continue(data)
  end
}
```

### Type Validation

Check data types:

```ruby
step :validate_types, ->(result) {
  data = result.value
  errors = []

  unless data[:age].is_a?(Integer)
    errors << "age must be an integer"
  end

  unless data[:email].is_a?(String)
    errors << "email must be a string"
  end

  if errors.any?
    result.halt.with_error(:type, errors.join(", "))
  else
    result.continue(data)
  end
}
```

### Range Validation

Validate numeric ranges:

```ruby
step :validate_ranges, ->(result) {
  data = result.value

  if data[:age] < 0 || data[:age] > 120
    return result.halt.with_error(:range, "Age must be between 0 and 120")
  end

  if data[:quantity] < 1
    return result.halt.with_error(:range, "Quantity must be at least 1")
  end

  result.continue(data)
}
```

## Real-World Example

Complete error handling in an order processing pipeline:

```ruby
order_pipeline = SimpleFlow::Pipeline.new do
  # Validate order structure
  step :validate_order, ->(result) {
    order = result.value
    errors = []

    errors << "Missing customer email" unless order[:customer][:email]
    errors << "No items in order" if order[:items].empty?
    errors << "Missing payment method" unless order[:payment][:card_token]

    if errors.any?
      result.halt.with_error(:validation, errors.join(", "))
    else
      result.with_context(:validated_at, Time.now).continue(order)
    end
  }, depends_on: []

  # Check inventory with error handling
  step :check_inventory, ->(result) {
    begin
      inventory_results = InventoryService.check_availability(result.value[:items])

      if inventory_results.all? { |r| r[:available] }
        result.with_context(:inventory_check, inventory_results).continue(result.value)
      else
        unavailable = inventory_results.reject { |r| r[:available] }
        result.halt.with_error(
          :inventory,
          "Items unavailable: #{unavailable.map { |i| i[:product_id] }.join(', ')}"
        )
      end
    rescue InventoryService::Error => e
      result.halt.with_error(:service, "Inventory service error: #{e.message}")
    end
  }, depends_on: [:validate_order]

  # Process payment with retries
  step :process_payment, ->(result) {
    total = result.context[:total]

    payment_result = PaymentService.process_payment(
      total,
      result.value[:payment][:card_token]
    )

    case payment_result[:status]
    when :success
      result.with_context(:payment, payment_result).continue(result.value)
    when :declined
      result.halt.with_error(:payment, "Card declined: #{payment_result[:reason]}")
    when :insufficient_funds
      result.halt.with_error(:payment, "Insufficient funds")
    else
      result.halt.with_error(:payment, "Payment processing failed")
    end
  }, depends_on: [:check_inventory]
end

# Execute and handle errors
result = order_pipeline.call_parallel(order_data)

if result.continue?
  puts "Order processed successfully"
  send_confirmation_email(result.value)
else
  puts "Order failed:"
  result.errors.each do |category, messages|
    puts "  #{category}: #{messages.join(', ')}"
  end

  # Handle specific error types
  if result.errors[:payment]
    log_payment_failure(result.value)
  elsif result.errors[:inventory]
    notify_inventory_team(result.value)
  end
end
```

## Related Documentation

- [Validation Patterns](validation-patterns.md) - Common validation strategies
- [Complex Workflows](complex-workflows.md) - Building sophisticated pipelines
- [Result API](../api/result.md) - Complete Result class reference
- [Pipeline API](../api/pipeline.md) - Pipeline class reference
