# Middleware

Middleware provides a way to add cross-cutting concerns to your pipeline without modifying individual steps.

## Overview

Middleware wraps steps using the decorator pattern, allowing you to:

- Log step execution
- Measure performance
- Add authentication/authorization
- Handle retries
- Cache results
- Track metrics

## Built-in Middleware

### Logging Middleware

Logs before and after each step execution:

```ruby
require 'simple_flow'

pipeline = SimpleFlow::Pipeline.new do
  use SimpleFlow::MiddleWare::Logging

  step ->(result) { result.continue(process_data(result.value)) }
  step ->(result) { result.continue(validate_data(result.value)) }
end
```

Output:
```
[SimpleFlow] Before step: #<Proc:0x00007f8b1c0b4f00>
[SimpleFlow] After step: #<Proc:0x00007f8b1c0b4f00>
[SimpleFlow] Before step: #<Proc:0x00007f8b1c0b5200>
[SimpleFlow] After step: #<Proc:0x00007f8b1c0b5200>
```

### Instrumentation Middleware

Measures execution time and tracks API usage:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use SimpleFlow::MiddleWare::Instrumentation, api_key: 'my-app-key'

  step ->(result) { result.continue(fetch_data(result.value)) }
  step ->(result) { result.continue(process_data(result.value)) }
end
```

Output:
```
Instrumentation: my-app-key took 0.0423s
Instrumentation: my-app-key took 0.0156s
```

## Creating Custom Middleware

Middleware is any class that:

1. Accepts a `callable` and optional `options` in its initializer
2. Implements a `call(result)` method
3. Calls `@callable.call(result)` to execute the wrapped step

### Basic Template

```ruby
class MyMiddleware
  def initialize(callable, **options)
    @callable = callable
    @options = options
  end

  def call(result)
    # Before logic
    puts "Before step with options: #{@options.inspect}"

    # Execute the step
    result = @callable.call(result)

    # After logic
    puts "After step, value: #{result.value.inspect}"

    result
  end
end
```

### Example: Retry Middleware

```ruby
class RetryMiddleware
  def initialize(callable, max_retries: 3, backoff: 1.0)
    @callable = callable
    @max_retries = max_retries
    @backoff = backoff
  end

  def call(result)
    attempts = 0

    begin
      @callable.call(result)
    rescue StandardError => e
      attempts += 1

      if attempts < @max_retries
        sleep(@backoff * attempts)
        retry
      else
        result.with_error(:retry_exhausted, e.message).halt
      end
    end
  end
end

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use RetryMiddleware, max_retries: 5, backoff: 2.0

  step ->(result) {
    # This will be retried up to 5 times
    data = unreliable_api_call(result.value)
    result.continue(data)
  }
end
```

### Example: Authentication Middleware

```ruby
class AuthenticationMiddleware
  def initialize(callable, required_role: nil)
    @callable = callable
    @required_role = required_role
  end

  def call(result)
    user = result.context[:current_user]

    unless user
      return result
        .with_error(:authentication, 'User not authenticated')
        .halt
    end

    if @required_role && !user.has_role?(@required_role)
      return result
        .with_error(:authorization, "Requires #{@required_role} role")
        .halt
    end

    @callable.call(result)
  end
end

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use AuthenticationMiddleware, required_role: :admin

  step ->(result) {
    # This only runs if user is authenticated and has admin role
    result.continue(sensitive_operation(result.value))
  }
end
```

### Example: Caching Middleware

```ruby
class CachingMiddleware
  def initialize(callable, cache:, ttl: 3600)
    @callable = callable
    @cache = cache
    @ttl = ttl
  end

  def call(result)
    cache_key = generate_cache_key(result)

    # Try cache first
    if cached = @cache.get(cache_key)
      return result
        .continue(cached)
        .with_context(:cache_hit, true)
    end

    # Execute step
    result = @callable.call(result)

    # Cache the result
    @cache.set(cache_key, result.value, ttl: @ttl) if result.continue?

    result.with_context(:cache_hit, false)
  end

  private

  def generate_cache_key(result)
    Digest::MD5.hexdigest(result.value.to_json)
  end
end

# Usage
pipeline = SimpleFlow::Pipeline.new do
  use CachingMiddleware, cache: Redis.new, ttl: 1800

  step ->(result) {
    # Expensive operation that will be cached
    data = expensive_database_query(result.value)
    result.continue(data)
  }
end
```

## Middleware Order

Middleware is applied in reverse order (last declared = innermost wrapper):

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use MiddlewareA  # Applied third (outermost)
  use MiddlewareB  # Applied second
  use MiddlewareC  # Applied first (innermost)

  step ->(result) { result.continue('data') }
end
```

Execution order:
```
MiddlewareA before
  MiddlewareB before
    MiddlewareC before
      Step executes
    MiddlewareC after
  MiddlewareB after
MiddlewareA after
```

## Combining Multiple Middleware

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Logging (outermost)
  use SimpleFlow::MiddleWare::Logging

  # Authentication
  use AuthenticationMiddleware, required_role: :user

  # Caching
  use CachingMiddleware, cache: Rails.cache

  # Retry logic
  use RetryMiddleware, max_retries: 3

  # Instrumentation (innermost)
  use SimpleFlow::MiddleWare::Instrumentation, api_key: 'app'

  step ->(result) { result.continue(process(result.value)) }
end
```

## Conditional Middleware

Apply middleware based on conditions:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use SimpleFlow::MiddleWare::Logging if ENV['DEBUG']
  use CachingMiddleware, cache: cache if Rails.env.production?

  step ->(result) { result.continue(process(result.value)) }
end
```

## Testing Middleware

```ruby
require 'minitest/autorun'

class MyMiddlewareTest < Minitest::Test
  def test_middleware_execution
    step = ->(result) { result.continue('processed') }
    middleware = MyMiddleware.new(step, option: 'value')

    input = SimpleFlow::Result.new('input')
    output = middleware.call(input)

    assert_equal 'processed', output.value
  end

  def test_middleware_adds_context
    step = ->(result) { result.continue(result.value) }
    middleware = TimingMiddleware.new(step)

    input = SimpleFlow::Result.new('data')
    output = middleware.call(input)

    assert output.context[:execution_time]
  end
end
```

## Best Practices

1. **Keep middleware focused**: Each middleware should handle one concern
2. **Preserve the result**: Always call `@callable.call(result)`
3. **Don't swallow errors**: Let exceptions propagate unless you're handling retries
4. **Use context for metadata**: Add timing, cache hits, etc. to context
5. **Make options explicit**: Use keyword arguments for clarity
6. **Test in isolation**: Middleware should be independently testable
7. **Document side effects**: Clearly document any state changes

## Common Use Cases

### Performance Monitoring

```ruby
class PerformanceMiddleware
  def initialize(callable, threshold: 1.0)
    @callable = callable
    @threshold = threshold
  end

  def call(result)
    start_time = Time.now
    result = @callable.call(result)
    duration = Time.now - start_time

    if duration > @threshold
      warn "Slow step: #{duration}s (threshold: #{@threshold}s)"
    end

    result.with_context(:duration, duration)
  end
end
```

### Error Enrichment

```ruby
class ErrorEnrichmentMiddleware
  def initialize(callable)
    @callable = callable
  end

  def call(result)
    @callable.call(result)
  rescue StandardError => e
    result
      .with_error(:exception, e.message)
      .with_context(:exception_class, e.class.name)
      .with_context(:backtrace, e.backtrace.first(5))
      .halt
  end
end
```

### Request ID Tracking

```ruby
class RequestIDMiddleware
  def initialize(callable)
    @callable = callable
  end

  def call(result)
    request_id = result.context[:request_id] || SecureRandom.uuid

    result_with_id = result.with_context(:request_id, request_id)

    Thread.current[:request_id] = request_id
    result = @callable.call(result_with_id)
    Thread.current[:request_id] = nil

    result
  end
end
```

## Next Steps

- [Pipeline](pipeline.md) - Learn how middleware integrates with pipelines
- [Flow Control](flow-control.md) - Controlling execution flow
- [Error Handling Guide](../guides/error-handling.md) - Comprehensive error strategies
