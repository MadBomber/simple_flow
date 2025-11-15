# Flow Control

Flow control in SimpleFlow allows you to manage the execution path of your pipeline based on conditions, errors, or business logic.

## Sequential Step Dependencies

**In sequential pipelines, each unnamed step automatically depends on the previous step's success.**

This means that steps execute in order, and the pipeline short-circuits (stops) as soon as any step halts:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "Step 1: Running"
    result.continue(result.value)
  }

  step ->(result) {
    puts "Step 2: Halting"
    result.halt("error occurred")
  }

  step ->(result) {
    puts "Step 3: This never runs"
    result.continue(result.value)
  }
end

result = pipeline.call(SimpleFlow::Result.new(nil))
# Output:
# Step 1: Running
# Step 2: Halting
# (Step 3 is skipped)
```

**Key points:**
- No need to explicitly define dependencies for sequential workflows
- Each step receives the result from the previous step
- Halting a step prevents all subsequent steps from executing
- This is the default behavior for unnamed steps using `pipeline.call(result)`

## The Continue Flag

Every `Result` has a `continue?` method that determines whether the pipeline should proceed:

```ruby
result = SimpleFlow::Result.new(data)
result.continue?  # => true (default)

result = result.halt
result.continue?  # => false
```

## Halting Execution

### Basic Halt

Stop the pipeline while preserving the current value:

```ruby
step ->(result) do
  if should_stop?(result.value)
    return result.halt
  end

  result.continue(process(result.value))
end
```

### Halt with New Value

Stop the pipeline with a different value (e.g., error response):

```ruby
step ->(result) do
  unless valid?(result.value)
    error_response = { error: 'Invalid data' }
    return result.halt(error_response)
  end

  result.continue(result.value)
end
```

## Continue After Halt

Once halted, a result stays halted even if you try to continue:

```ruby
result = SimpleFlow::Result.new(data)
  .halt
  .continue('new value')

result.continue?  # => false (still halted)
result.value      # => 'new value' (value changed, but still halted)
```

## Conditional Execution

### Early Return Pattern

```ruby
step ->(result) do
  # Skip processing if conditions not met
  return result.continue(result.value) if skip_condition?(result)

  # Process normally
  processed = expensive_operation(result.value)
  result.continue(processed)
end
```

### Guard Clauses

```ruby
step ->(result) do
  data = result.value

  # Multiple guard clauses
  return result.with_error(:validation, 'ID required').halt unless data[:id]
  return result.with_error(:validation, 'Email required').halt unless data[:email]
  return result.with_error(:authorization, 'Unauthorized').halt unless authorized?(data)

  # Main logic
  result.continue(process(data))
end
```

### Branching Logic

```ruby
step ->(result) do
  user_type = result.value[:type]

  case user_type
  when 'premium'
    result.continue(process_premium(result.value))
  when 'standard'
    result.continue(process_standard(result.value))
  when 'trial'
    result.continue(process_trial(result.value))
  else
    result.with_error(:validation, "Unknown type: #{user_type}").halt
  end
end
```

## Error-Based Flow Control

### Accumulate Errors, Continue Processing

```ruby
step ->(result) do
  data = result.value
  result_with_errors = result

  # Collect all validation errors
  if data[:name].blank?
    result_with_errors = result_with_errors.with_error(:validation, 'Name required')
  end

  if data[:email].blank?
    result_with_errors = result_with_errors.with_error(:validation, 'Email required')
  end

  if data[:age] && data[:age] < 18
    result_with_errors = result_with_errors.with_error(:validation, 'Must be 18+')
  end

  # Continue with errors tracked
  result_with_errors.continue(data)
end
```

### Halt on Critical Errors

```ruby
step ->(result) do
  data = result.value
  result_with_errors = result

  # Collect warnings (non-critical)
  if data[:phone].blank?
    result_with_errors = result_with_errors.with_error(:warning, 'Phone number recommended')
  end

  # Halt on critical errors
  if data[:credit_card].blank?
    return result_with_errors
      .with_error(:critical, 'Payment method required')
      .halt
  end

  result_with_errors.continue(data)
end
```

### Check Accumulated Errors

```ruby
step ->(result) do
  # Check if previous steps added errors
  if result.errors.key?(:validation)
    return result.halt  # Stop if validation errors exist
  end

  result.continue(process(result.value))
end
```

## Context-Based Flow Control

### Skip Steps Based on Context

```ruby
step ->(result) do
  # Skip if already processed
  if result.context[:processed]
    return result.continue(result.value)
  end

  processed = process_data(result.value)
  result
    .continue(processed)
    .with_context(:processed, true)
end
```

### Feature Flags

```ruby
step ->(result) do
  # Skip if feature disabled
  unless result.context[:feature_enabled]
    return result.continue(result.value)
  end

  new_feature_processing(result.value)
  result.continue(processed)
end
```

## Retry Logic

### Simple Retry

```ruby
step ->(result) do
  max_retries = 3
  attempts = 0

  begin
    data = unreliable_api_call(result.value)
    result.continue(data)
  rescue StandardError => e
    attempts += 1
    retry if attempts < max_retries

    result
      .with_error(:api, "Failed after #{attempts} attempts: #{e.message}")
      .halt
  end
end
```

### Exponential Backoff

```ruby
step ->(result) do
  max_retries = 5
  base_delay = 1.0
  attempts = 0

  begin
    data = fetch_external_data(result.value)
    result.continue(data)
  rescue StandardError => e
    attempts += 1

    if attempts < max_retries
      delay = base_delay * (2 ** (attempts - 1))
      sleep(delay)
      retry
    end

    result
      .with_error(:external, "Max retries exceeded: #{e.message}")
      .with_context(:retry_attempts, attempts)
      .halt
  end
end
```

## Circuit Breaker Pattern

```ruby
class CircuitBreaker
  def initialize
    @failure_count = 0
    @last_failure_time = nil
    @threshold = 5
    @timeout = 60
  end

  def call(result)
    # Check if circuit is open
    if circuit_open?
      return result
        .with_error(:circuit_breaker, 'Circuit breaker open')
        .halt
    end

    # Try operation
    begin
      data = risky_operation(result.value)
      reset_circuit
      result.continue(data)
    rescue StandardError => e
      record_failure
      result.with_error(:operation, e.message).halt
    end
  end

  private

  def circuit_open?
    @failure_count >= @threshold &&
      @last_failure_time &&
      (Time.now - @last_failure_time) < @timeout
  end

  def record_failure
    @failure_count += 1
    @last_failure_time = Time.now
  end

  def reset_circuit
    @failure_count = 0
    @last_failure_time = nil
  end
end
```

## Conditional Pipeline Construction

Build pipelines dynamically based on conditions:

```ruby
def build_pipeline(user_type)
  SimpleFlow::Pipeline.new do
    # Always validate
    step method(:validate_user)

    # Conditional steps based on user type
    if user_type == :premium
      step method(:apply_premium_discount)
      step method(:check_premium_limits)
    end

    if user_type == :enterprise
      step method(:check_bulk_pricing)
      step method(:assign_account_manager)
    end

    # Always process
    step method(:process_order)
  end
end
```

## Short-Circuit Entire Pipeline

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Pre-flight check - halts entire pipeline if fails
  step ->(result) do
    unless system_healthy?
      return result
        .with_error(:system, 'System maintenance in progress')
        .halt
    end
    result.continue(result.value)
  end

  # These only run if pre-flight passes
  step method(:process_data)
  step method(:validate_results)
  step method(:save_to_database)
end
```

## Best Practices

1. **Fail Fast**: Use `halt` as soon as you know processing cannot succeed
2. **Preserve Context**: Keep error messages and context for debugging
3. **Distinguish Error Severity**: Use different error categories (`:validation`, `:critical`, `:warning`)
4. **Use Early Returns**: Make guard clauses clear with early returns
5. **Document Flow Logic**: Comment complex conditional logic
6. **Test Both Paths**: Test both success and failure paths
7. **Avoid Deep Nesting**: Use early returns instead of nested conditionals

## Common Patterns

### Validation Pipeline

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) do
    # Collect all errors, but don't halt yet
    result_with_errors = validate_all_fields(result)

    # Halt only if errors exist
    if result_with_errors.errors.any?
      return result_with_errors.halt
    end

    result_with_errors.continue(result.value)
  end

  # This only runs if validation passed
  step method(:process_valid_data)
end
```

### Multi-Stage Processing

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Stage 1: Preparation (must succeed)
  step method(:fetch_data)
  step method(:validate_data)

  # Stage 2: Processing (optional based on flags)
  step ->(result) do
    if result.context[:skip_processing]
      return result.continue(result.value)
    end
    result.continue(process_data(result.value))
  end

  # Stage 3: Finalization (always runs if we got here)
  step method(:save_results)
  step method(:send_notifications)
end
```

## Next Steps

- [Result](result.md) - Understanding the Result object
- [Steps](steps.md) - Implementing step logic
- [Error Handling Guide](../guides/error-handling.md) - Comprehensive error handling strategies
- [Complex Workflows Guide](../guides/complex-workflows.md) - Real-world flow control examples
