# Result

The `Result` class is the fundamental value object in SimpleFlow that encapsulates the outcome of each operation in your pipeline.

## Overview

A `Result` object contains three main components:

- **Value**: The actual data being processed
- **Context**: A hash of metadata and contextual information
- **Errors**: Categorized error messages accumulated during processing

## Immutability

Results are immutable - every operation returns a new `Result` instance rather than modifying the existing one. This design promotes safer concurrent operations and functional programming patterns.

```ruby
original = SimpleFlow::Result.new("data")
updated = original.with_context(:user_id, 123)

original.context  # => {}
updated.context   # => { user_id: 123 }
```

## Creating Results

### Basic Initialization

```ruby
# Simple result with just a value
result = SimpleFlow::Result.new(10)

# Result with initial context and errors
result = SimpleFlow::Result.new(
  { count: 5 },
  context: { user_id: 123 },
  errors: { validation: ['Required field missing'] }
)
```

## Working with Context

Context allows you to pass metadata through your pipeline without modifying the primary value.

```ruby
result = SimpleFlow::Result.new(data)
  .with_context(:user_id, 123)
  .with_context(:timestamp, Time.now.to_i)
  .with_context(:source, 'api')

result.context
# => { user_id: 123, timestamp: 1234567890, source: 'api' }
```

### Common Context Use Cases

- User authentication details
- Request timestamps
- Transaction IDs
- Debug information
- Performance metrics

## Error Handling

Errors are organized by category, allowing multiple errors per category:

```ruby
result = SimpleFlow::Result.new(data)
  .with_error(:validation, 'Email is required')
  .with_error(:validation, 'Password too short')
  .with_error(:authentication, 'Invalid token')

result.errors
# => {
#   validation: ['Email is required', 'Password too short'],
#   authentication: ['Invalid token']
# }
```

## Flow Control

Results include a continue flag that controls pipeline execution.

### Continue

Move to the next step with a new value:

```ruby
result = result.continue(new_value)
# continue? => true
```

### Halt

Stop pipeline execution:

```ruby
# Halt without changing value
result = result.halt
# continue? => false, value unchanged

# Halt with a new value
result = result.halt(error_response)
# continue? => false, value changed
```

### Checking Status

```ruby
if result.continue?
  # Pipeline will proceed
else
  # Pipeline has been halted
end
```

## Example: Multi-Step Processing

```ruby
def process_user_registration(params)
  result = SimpleFlow::Result.new(params)
    .with_context(:ip_address, request.ip)
    .with_context(:timestamp, Time.now)

  # Validation
  if params[:email].nil?
    return result
      .with_error(:validation, 'Email required')
      .halt
  end

  # Process
  user = create_user(params)

  result
    .continue(user)
    .with_context(:user_id, user.id)
end
```

## API Reference

### Instance Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `value` | Get the current value | Object |
| `context` | Get the context hash | Hash |
| `errors` | Get the errors hash | Hash |
| `continue?` | Check if pipeline should continue | Boolean |
| `with_context(key, value)` | Add context | New Result |
| `with_error(key, message)` | Add error | New Result |
| `continue(new_value)` | Proceed with new value | New Result |
| `halt(new_value = nil)` | Stop execution | New Result |

## Best Practices

1. **Use context for metadata**: Keep the value focused on the data being processed
2. **Categorize errors**: Use meaningful error keys like `:validation`, `:authentication`, `:database`
3. **Halt early**: Stop processing as soon as you know the operation cannot succeed
4. **Chain operations**: Take advantage of immutability to build readable operation chains
5. **Preserve information**: When halting, preserve context and errors for debugging

## Next Steps

- [Pipeline](pipeline.md) - Learn how Results flow through pipelines
- [Flow Control](flow-control.md) - Advanced flow control patterns
- [Error Handling Guide](../guides/error-handling.md) - Comprehensive error handling strategies
