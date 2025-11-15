# Quick Start

Get up and running with SimpleFlow in 5 minutes!

## Your First Pipeline

```ruby
require 'simple_flow'

# Create a simple text processing pipeline
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value.strip) }
  step ->(result) { result.continue(result.value.downcase) }
  step ->(result) { result.continue("Hello, #{result.value}!") }
end

# Execute the pipeline
result = pipeline.call(SimpleFlow::Result.new("  WORLD  "))
puts result.value
# => "Hello, world!"
```

## Understanding the Basics

### Sequential Execution

**Steps execute in order, with each step automatically depending on the previous step's success.**

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { puts "Step 1"; result.continue(result.value) }
  step ->(result) { puts "Step 2"; result.halt("error") }  # Stops here
  step ->(result) { puts "Step 3"; result.continue(result.value) }  # Never runs
end

result = pipeline.call(SimpleFlow::Result.new(nil))
# Output: Step 1
#         Step 2
# (Step 3 is skipped because Step 2 halted)
```

When any step halts (returns `result.halt`), the pipeline stops immediately and subsequent steps are not executed.

### 1. Create a Result

A `Result` wraps your data:

```ruby
result = SimpleFlow::Result.new(42)
```

### 2. Define Steps

Steps are callable objects (usually lambdas) that transform results:

```ruby
step ->(result) {
  new_value = result.value * 2
  result.continue(new_value)
}
```

### 3. Build a Pipeline

Combine steps into a pipeline:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 10) }
  step ->(result) { result.continue(result.value * 2) }
end
```

### 4. Execute

Call the pipeline with an initial result:

```ruby
final = pipeline.call(SimpleFlow::Result.new(5))
puts final.value  # => 30  ((5 + 10) * 2)
```

## Adding Context

Track metadata throughout your pipeline:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    result
      .with_context(:started_at, Time.now)
      .continue(result.value)
  }

  step ->(result) {
    result
      .with_context(:user, "Alice")
      .continue(result.value.upcase)
  }
end

result = pipeline.call(SimpleFlow::Result.new("hello"))
puts result.value    # => "HELLO"
puts result.context  # => {:started_at=>..., :user=>"Alice"}
```

## Error Handling

Accumulate errors and halt execution:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    age = result.value
    if age < 18
      result.halt.with_error(:age, "Must be 18 or older")
    else
      result.continue(age)
    end
  }

  step ->(result) {
    # This won't execute if age < 18
    result.continue("Approved for age #{result.value}")
  }
end

result = pipeline.call(SimpleFlow::Result.new(16))
puts result.continue?  # => false
puts result.errors     # => {:age=>["Must be 18 or older"]}
```

## Concurrent Execution

Run independent steps in parallel:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  parallel do
    step ->(result) { result.with_context(:a, fetch_data_a).continue(result.value) }
    step ->(result) { result.with_context(:b, fetch_data_b).continue(result.value) }
    step ->(result) { result.with_context(:c, fetch_data_c).continue(result.value) }
  end

  step ->(result) {
    # All three fetches completed concurrently
    result.continue("Aggregated data")
  }
end
```

## Middleware

Add cross-cutting concerns:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging

  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value * 2) }
end

# Logs before and after each step
```

## Real-World Example

Here's a more complete example:

```ruby
require 'simple_flow'

# Define validation steps
validate_email = ->(result) {
  email = result.value[:email]
  if email && email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)+\z/i)
    result.continue(result.value)
  else
    result.halt(result.value).with_error(:email, "Invalid email format")
  end
}

validate_age = ->(result) {
  age = result.value[:age]
  if age && age >= 18
    result.continue(result.value)
  else
    result.halt(result.value).with_error(:age, "Must be 18 or older")
  end
}

# Build validation pipeline
validation_pipeline = SimpleFlow::Pipeline.new do
  step validate_email
  step validate_age
end

# Test with valid data
valid_data = { email: "alice@example.com", age: 25 }
result = validation_pipeline.call(SimpleFlow::Result.new(valid_data))
puts result.continue?  # => true

# Test with invalid data
invalid_data = { email: "invalid", age: 16 }
result = validation_pipeline.call(SimpleFlow::Result.new(invalid_data))
puts result.continue?  # => false
puts result.errors     # => {:email=>["Invalid email format"]}
```

## Next Steps

Now that you've got the basics, explore:

- [Examples](examples.md) - Real-world use cases
- [Core Concepts](../core-concepts/overview.md) - Deep dive into architecture
- [Concurrent Execution](../concurrent/introduction.md) - Maximize performance
- [Error Handling Guide](../guides/error-handling.md) - Advanced error patterns
