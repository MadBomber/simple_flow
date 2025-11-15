# Steps

Steps are the individual operations that make up your pipeline. Each step receives a Result and returns a Result.

## Step Types

SimpleFlow supports any callable object as a step:

### 1. Lambda/Proc

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) do
    new_value = result.value.upcase
    result.continue(new_value)
  end
end
```

### 2. Method References

```ruby
def validate_email(result)
  if result.value[:email] =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    result.continue(result.value)
  else
    result.with_error(:validation, 'Invalid email').halt
  end
end

pipeline = SimpleFlow::Pipeline.new do
  step method(:validate_email)
end
```

### 3. Callable Objects

```ruby
class UserValidator
  def call(result)
    user = result.value

    errors = []
    errors << 'Name required' if user[:name].blank?
    errors << 'Email required' if user[:email].blank?

    if errors.any?
      errors.each { |error| result = result.with_error(:validation, error) }
      return result.halt
    end

    result.continue(user)
  end
end

pipeline = SimpleFlow::Pipeline.new do
  step UserValidator.new
end
```

### 4. Class Methods

```ruby
class DataTransformer
  def self.call(result)
    transformed = transform_data(result.value)
    result.continue(transformed)
  end

  def self.transform_data(data)
    # Transformation logic
    data.transform_values(&:to_s)
  end
end

pipeline = SimpleFlow::Pipeline.new do
  step DataTransformer
end
```

## Anonymous vs Named Steps

### Anonymous Steps

Simple, sequential steps without explicit dependencies:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value * 2) }
  step ->(result) { result.continue(result.value + 10) }
end
```

### Named Steps

Steps with explicit names and dependencies for parallel execution:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, ->(result) { fetch_user(result) }, depends_on: []
  step :fetch_orders, ->(result) { fetch_orders(result) }, depends_on: [:fetch_user]
end
```

## Step Contract

Every step must:

1. Accept a `Result` object as input
2. Return a `Result` object as output
3. Use `.continue(value)` to proceed
4. Use `.halt(value)` to stop the pipeline

```ruby
# ✅ Good - follows contract
def my_step(result)
  processed = process(result.value)
  result.continue(processed)
end

# ❌ Bad - returns wrong type
def bad_step(result)
  result.value * 2  # Returns a number, not a Result
end

# ❌ Bad - doesn't accept Result
def bad_step(value)
  value * 2
end
```

## Working with Values

### Transforming Values

```ruby
step ->(result) do
  # Get current value
  data = result.value

  # Transform it
  transformed = data.map { |item| item.upcase }

  # Continue with new value
  result.continue(transformed)
end
```

### Modifying Nested Data

```ruby
step ->(result) do
  user = result.value
  user[:processed_at] = Time.now
  result.continue(user)
end
```

## Adding Context

Context persists across steps without modifying the value:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    result
      .continue(result.value)
      .with_context(:started_at, Time.now)
  }

  step ->(result) {
    result
      .continue(process(result.value))
      .with_context(:processed_at, Time.now)
  }

  step ->(result) {
    duration = result.context[:processed_at] - result.context[:started_at]
    result
      .continue(result.value)
      .with_context(:duration, duration)
  }
end
```

## Error Handling in Steps

### Collecting Errors

```ruby
step ->(result) do
  user = result.value
  result_with_errors = result

  if user[:email].nil?
    result_with_errors = result_with_errors.with_error(:validation, 'Email required')
  end

  if user[:age] && user[:age] < 18
    result_with_errors = result_with_errors.with_error(:validation, 'Must be 18+')
  end

  # Continue even with errors (they're tracked)
  result_with_errors.continue(user)
end
```

### Halting on Errors

```ruby
step ->(result) do
  if critical_error?(result.value)
    return result
      .with_error(:critical, 'Cannot proceed')
      .halt
  end

  result.continue(result.value)
end
```

## Conditional Logic

### Early Return

```ruby
step ->(result) do
  return result.halt if should_skip?(result.value)

  result.continue(process(result.value))
end
```

### Branching

```ruby
step ->(result) do
  if result.value[:type] == 'premium'
    result.continue(process_premium(result.value))
  else
    result.continue(process_standard(result.value))
  end
end
```

## Async/External Operations

Steps can perform I/O operations:

```ruby
step ->(result) do
  # API call
  response = HTTParty.get("https://api.example.com/users/#{result.value[:id]}")

  result
    .continue(response.parsed_response)
    .with_context(:api_response_time, response.headers['x-response-time'])
end
```

## Testing Steps

Steps are easy to test in isolation:

```ruby
require 'minitest/autorun'

class StepTest < Minitest::Test
  def test_validation_step
    result = SimpleFlow::Result.new({ email: 'test@example.com' })
    output = validate_email(result)

    assert output.continue?
    assert_empty output.errors
  end

  def test_validation_step_with_invalid_email
    result = SimpleFlow::Result.new({ email: 'invalid' })
    output = validate_email(result)

    refute output.continue?
    assert_includes output.errors[:validation], 'Invalid email'
  end
end
```

## Best Practices

1. **Single Responsibility**: Each step should do one thing
2. **Pure Functions**: Avoid side effects when possible
3. **Explicit Dependencies**: Use named steps with `depends_on` for clarity
4. **Error Context**: Include helpful error messages with context
5. **Testability**: Design steps to be easily testable in isolation
6. **Immutability**: Never modify the input result - always return a new one
7. **Meaningful Names**: For named steps, use descriptive names

## Performance Considerations

### I/O-Bound Steps

Use parallel execution for independent I/O operations:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :validate, validator, depends_on: []

  # These run in parallel
  step :fetch_user_data, fetch_user, depends_on: [:validate]
  step :fetch_order_data, fetch_orders, depends_on: [:validate]
  step :fetch_product_data, fetch_products, depends_on: [:validate]
end
```

### CPU-Bound Steps

Keep CPU-intensive operations sequential (Ruby GIL limitation):

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { heavy_computation_1(result) }
  step ->(result) { heavy_computation_2(result) }
end
```

## Next Steps

- [Pipeline](pipeline.md) - Learn how steps are orchestrated
- [Flow Control](flow-control.md) - Advanced flow control patterns
- [Parallel Execution](../concurrent/parallel-steps.md) - Concurrent step execution
- [Error Handling Guide](../guides/error-handling.md) - Comprehensive error handling
