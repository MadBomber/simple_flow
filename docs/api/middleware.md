# Middleware API Reference

Middleware in SimpleFlow wraps steps with cross-cutting functionality using the decorator pattern. This document covers built-in middleware and how to create custom middleware.

## Built-in Middleware

### Class: `SimpleFlow::MiddleWare::Logging`

**Location**: `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/lib/simple_flow/middleware.rb`

Logs before and after step execution.

#### Constructor

```ruby
def initialize(callable, logger = nil)
```

**Parameters:**
- `callable` (Proc/Object) - The step to wrap
- `logger` (Logger, optional) - Custom logger instance (default: `Logger.new($stdout)`)

#### Usage

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging

  step ->(result) { result.continue(process(result.value)) }
end
```

**With Custom Logger:**
```ruby
require 'logger'

custom_logger = Logger.new('pipeline.log')
custom_logger.level = Logger::DEBUG

pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging, logger: custom_logger

  step ->(result) { result.continue(result.value) }
end
```

**Output:**
```
I, [2025-11-15T12:00:00.123456 #12345]  INFO -- : Before call
I, [2025-11-15T12:00:00.456789 #12345]  INFO -- : After call
```

### Class: `SimpleFlow::MiddleWare::Instrumentation`

**Location**: `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/lib/simple_flow/middleware.rb`

Measures step execution duration.

#### Constructor

```ruby
def initialize(callable, api_key: nil)
```

**Parameters:**
- `callable` (Proc/Object) - The step to wrap
- `api_key` (String, optional) - API key for external instrumentation service

#### Usage

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'demo-key-123'

  step ->(result) {
    sleep 0.1
    result.continue(result.value)
  }
end
```

**Output:**
```
Instrumentation: demo-key-123 took 0.10012345s
```

## Creating Custom Middleware

### Basic Pattern

Custom middleware must implement a `call` method that:
1. Receives a Result object
2. Calls the wrapped callable
3. Returns a Result object

```ruby
class MyMiddleware
  def initialize(callable, **options)
    @callable = callable
    @options = options
  end

  def call(result)
    # Before step execution
    puts "Before: #{result.value}"

    # Execute the wrapped step
    output = @callable.call(result)

    # After step execution
    puts "After: #{output.value}"

    output
  end
end

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use_middleware MyMiddleware, option: "value"

  step ->(result) { result.continue(result.value) }
end
```

### Middleware Examples

#### Timing Middleware

```ruby
class TimingMiddleware
  def initialize(callable, step_name: nil)
    @callable = callable
    @step_name = step_name || "unknown_step"
  end

  def call(result)
    start_time = Time.now
    output = @callable.call(result)
    duration = Time.now - start_time

    output.with_context(
      "#{@step_name}_duration".to_sym,
      duration
    )
  end
end

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use_middleware TimingMiddleware, step_name: "data_processing"

  step ->(result) {
    process_data(result.value)
    result.continue(result.value)
  }
end

result = pipeline.call(initial_data)
puts "Execution time: #{result.context[:data_processing_duration]}s"
```

#### Retry Middleware

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

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use_middleware RetryMiddleware, max_retries: 3, retry_on: [Net::HTTPError]

  step ->(result) {
    data = fetch_from_api(result.value)  # May fail temporarily
    result.continue(data)
  }
end
```

#### Authentication Middleware

```ruby
class AuthMiddleware
  def initialize(callable, required_role:)
    @callable = callable
    @required_role = required_role
  end

  def call(result)
    user_role = result.context[:user_role]

    unless user_role == @required_role
      return result.halt.with_error(
        :auth,
        "Unauthorized: requires #{@required_role} role"
      )
    end

    @callable.call(result)
  end
end

# Usage
pipeline = SimpleFlow::Pipeline.new do
  # Set user role in first step
  step ->(result) {
    result.with_context(:user_role, :admin).continue(result.value)
  }

  # Protect subsequent steps
  use_middleware AuthMiddleware, required_role: :admin

  step ->(result) {
    # This only executes if user_role == :admin
    result.continue("Sensitive operation")
  }
end
```

#### Caching Middleware

```ruby
class CachingMiddleware
  def initialize(callable, cache_key_proc:, ttl: 3600)
    @callable = callable
    @cache_key_proc = cache_key_proc
    @ttl = ttl
  end

  def call(result)
    cache_key = @cache_key_proc.call(result)

    # Check cache
    if cached = REDIS.get(cache_key)
      return result.with_context(:cache_hit, true).continue(JSON.parse(cached))
    end

    # Execute step
    output = @callable.call(result)

    # Cache result if successful
    if output.continue?
      REDIS.setex(cache_key, @ttl, output.value.to_json)
    end

    output.with_context(:cache_hit, false)
  end
end

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use_middleware CachingMiddleware,
    cache_key_proc: ->(result) { "user_#{result.value}" },
    ttl: 1800

  step ->(result) {
    user = User.find(result.value)
    result.continue(user)
  }
end
```

#### Error Tracking Middleware

```ruby
class ErrorTrackingMiddleware
  def initialize(callable, error_tracker:)
    @callable = callable
    @error_tracker = error_tracker
  end

  def call(result)
    output = @callable.call(result)

    # Report errors to tracking service
    if !output.continue? && output.errors.any?
      @error_tracker.report(
        errors: output.errors,
        context: output.context,
        value: output.value
      )
    end

    output
  end
end

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use_middleware ErrorTrackingMiddleware, error_tracker: Sentry

  step ->(result) {
    # Errors here will be reported to Sentry
    result.halt.with_error(:processing, "Something went wrong")
  }
end
```

## Middleware Stacking

Middleware is applied in reverse order (last declared middleware wraps first):

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware OuterMiddleware     # Applied third (outermost)
  use_middleware MiddleMiddleware    # Applied second
  use_middleware InnerMiddleware     # Applied first (innermost)

  step ->(result) { result.continue(result.value) }
end

# Execution order:
# 1. OuterMiddleware before
# 2. MiddleMiddleware before
# 3. InnerMiddleware before
# 4. Step execution
# 5. InnerMiddleware after
# 6. MiddleMiddleware after
# 7. OuterMiddleware after
```

**Example:**
```ruby
class LoggingMiddleware
  def initialize(callable, name:)
    @callable = callable
    @name = name
  end

  def call(result)
    puts "#{@name}: before"
    output = @callable.call(result)
    puts "#{@name}: after"
    output
  end
end

pipeline = SimpleFlow::Pipeline.new do
  use_middleware LoggingMiddleware, name: "Outer"
  use_middleware LoggingMiddleware, name: "Middle"
  use_middleware LoggingMiddleware, name: "Inner"

  step ->(result) {
    puts "Step execution"
    result.continue(result.value)
  }
end

pipeline.call(SimpleFlow::Result.new(nil))

# Output:
# Outer: before
# Middle: before
# Inner: before
# Step execution
# Inner: after
# Middle: after
# Outer: after
```

## Best Practices

### 1. Keep Middleware Focused

Each middleware should have a single responsibility:

```ruby
# GOOD: Focused middleware
class TimingMiddleware
  def call(result)
    start = Time.now
    output = @callable.call(result)
    output.with_context(:duration, Time.now - start)
  end
end

# BAD: Too many responsibilities
class KitchenSinkMiddleware
  def call(result)
    # Logging, timing, caching, retrying, auth... too much!
  end
end
```

### 2. Preserve Result Immutability

Always return new Result objects:

```ruby
# GOOD: Returns new Result
def call(result)
  output = @callable.call(result)
  output.with_context(:middleware_applied, true)
end

# BAD: Attempts to modify Result
def call(result)
  output = @callable.call(result)
  output.context[:middleware_applied] = true  # Won't work!
  output
end
```

### 3. Handle Errors Gracefully

Ensure middleware doesn't break the pipeline:

```ruby
class SafeMiddleware
  def call(result)
    begin
      @callable.call(result)
    rescue StandardError => e
      result.halt.with_error(:middleware_error, "Middleware failed: #{e.message}")
    end
  end
end
```

### 4. Make Middleware Configurable

Use options for flexibility:

```ruby
class ConfigurableMiddleware
  def initialize(callable, enabled: true, **options)
    @callable = callable
    @enabled = enabled
    @options = options
  end

  def call(result)
    return @callable.call(result) unless @enabled

    # Middleware logic here
    @callable.call(result)
  end
end
```

## Related Documentation

- [Pipeline API](pipeline.md) - How pipelines use middleware
- [Complex Workflows](../guides/complex-workflows.md) - Using middleware in workflows
- [Error Handling](../guides/error-handling.md) - Error handling patterns
