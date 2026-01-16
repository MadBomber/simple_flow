# Result API Reference

The `Result` class is an immutable value object that represents the outcome of a step in a SimpleFlow pipeline. It encapsulates the operation's value, contextual data, and any errors that occurred.

## Class: `SimpleFlow::Result`

**Location**: `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/lib/simple_flow/result.rb`

### Constructor

#### `new(value, context: {}, errors: {}, activated_steps: [])`

Creates a new Result instance.

**Parameters:**
- `value` (Object) - The outcome of the operation
- `context` (Hash, optional) - Contextual data related to the operation (default: `{}`)
- `errors` (Hash, optional) - Errors organized by category (default: `{}`)
- `activated_steps` (Array, optional) - Steps to activate for dynamic execution (default: `[]`)

**Returns:** Result instance

**Example:**
```ruby
# Basic result
result = SimpleFlow::Result.new(42)

# Result with context
result = SimpleFlow::Result.new(
  { user_id: 123 },
  context: { timestamp: Time.now }
)

# Result with errors
result = SimpleFlow::Result.new(
  nil,
  errors: { validation: ["Email is required"] }
)
```

### Instance Attributes

#### `value`

The outcome of the operation.

**Type:** Object (read-only)

**Example:**
```ruby
result = SimpleFlow::Result.new(42)
result.value  # => 42
```

#### `context`

Contextual data related to the operation.

**Type:** Hash (read-only)

**Example:**
```ruby
result = SimpleFlow::Result.new(42, context: { user: "John" })
result.context  # => { user: "John" }
```

#### `errors`

Errors that occurred during the operation, organized by category.

**Type:** Hash (read-only)

**Example:**
```ruby
result = SimpleFlow::Result.new(nil, errors: {
  validation: ["Email required", "Password too short"],
  auth: ["Invalid credentials"]
})

result.errors[:validation]  # => ["Email required", "Password too short"]
result.errors[:auth]        # => ["Invalid credentials"]
```

#### `activated_steps`

Steps that have been activated for dynamic execution.

**Type:** Array (read-only)

**Example:**
```ruby
result = SimpleFlow::Result.new(42)
result.activated_steps  # => []

result = result.activate(:process_pdf, :send_notification)
result.activated_steps  # => [:process_pdf, :send_notification]
```

### Instance Methods

#### `with_context(key, value)`

Adds or updates context to the result. Returns a new Result instance with updated context.

**Parameters:**
- `key` (Symbol) - The key to store the context under
- `value` (Object) - The value to store

**Returns:** New Result instance

**Immutability:** This method creates a new Result object; the original is unchanged.

**Example:**
```ruby
result = SimpleFlow::Result.new(42)
  .with_context(:user_id, 123)
  .with_context(:timestamp, Time.now)

result.context  # => { user_id: 123, timestamp: 2025-11-15 12:00:00 }
```

**Chaining:**
```ruby
result = SimpleFlow::Result.new(data)
  .with_context(:step_name, "process_data")
  .with_context(:duration, 0.5)
  .with_context(:source, :api)
```

#### `with_error(key, message)`

Adds an error message under a specific key. If the key already exists, the message is appended to existing errors. Returns a new Result instance with updated errors.

**Parameters:**
- `key` (Symbol) - The category under which to store the error
- `message` (String) - The error message

**Returns:** New Result instance

**Immutability:** Creates a new Result object.

**Example:**
```ruby
result = SimpleFlow::Result.new(nil)
  .with_error(:validation, "Email is required")
  .with_error(:validation, "Password too short")
  .with_error(:auth, "Invalid credentials")

result.errors
# => {
#      validation: ["Email is required", "Password too short"],
#      auth: ["Invalid credentials"]
#    }
```

**Error Accumulation:**
```ruby
result = SimpleFlow::Result.new(data)

# Add first validation error
result = result.with_error(:validation, "Name is required")

# Add second validation error (accumulates)
result = result.with_error(:validation, "Email is required")

result.errors[:validation]
# => ["Name is required", "Email is required"]
```

#### `halt(new_value = nil)`

Halts the pipeline flow. Optionally updates the result's value. Returns a new Result instance with `continue` set to false.

**Parameters:**
- `new_value` (Object, optional) - New value to set (default: keep current value)

**Returns:** New Result instance with `@continue = false`

**Example:**
```ruby
# Halt without changing value
result = SimpleFlow::Result.new(42).halt
result.continue?  # => false
result.value      # => 42

# Halt with new value
result = SimpleFlow::Result.new(42).halt(100)
result.continue?  # => false
result.value      # => 100

# Halt with error
result = SimpleFlow::Result.new(data)
  .halt
  .with_error(:validation, "Invalid input")

result.continue?  # => false
result.errors     # => { validation: ["Invalid input"] }
```

**Usage in Steps:**
```ruby
step ->(result) {
  if invalid?(result.value)
    result.halt.with_error(:validation, "Invalid data")
  else
    result.continue(process(result.value))
  end
}
```

#### `continue(new_value)`

Continues the pipeline flow with an updated value. Returns a new Result instance with the new value.

**Parameters:**
- `new_value` (Object) - The new value to set

**Returns:** New Result instance with updated value

**Example:**
```ruby
result = SimpleFlow::Result.new(5)
  .continue(10)

result.continue?  # => true
result.value      # => 10
```

**Usage in Steps:**
```ruby
step ->(result) {
  transformed = transform(result.value)
  result.continue(transformed)
}
```

#### `continue?`

Checks if the pipeline should continue executing.

**Returns:** Boolean
- `true` if the pipeline should continue
- `false` if the pipeline has been halted

**Example:**
```ruby
result = SimpleFlow::Result.new(42)
result.continue?  # => true

result = result.halt
result.continue?  # => false
```

**Usage:**
```ruby
result = pipeline.call(initial_data)

if result.continue?
  puts "Success: #{result.value}"
  process_result(result)
else
  puts "Failed: #{result.errors}"
  handle_errors(result)
end
```

#### `activate(*step_names)`

Activates optional steps for dynamic execution. Activated steps will be executed during `call_parallel` if they are declared with `depends_on: :optional`.

**Parameters:**
- `step_names` (Symbol, Array<Symbol>) - One or more step names to activate

**Returns:** New Result instance with steps added to `activated_steps`

**Immutability:** Creates a new Result object.

**Example:**
```ruby
# Activate a single step
result = SimpleFlow::Result.new(data).activate(:process_pdf)
result.activated_steps  # => [:process_pdf]

# Activate multiple steps at once
result = SimpleFlow::Result.new(data).activate(:step_a, :step_b, :step_c)
result.activated_steps  # => [:step_a, :step_b, :step_c]

# Chain activations
result = SimpleFlow::Result.new(data)
  .activate(:step_a)
  .activate(:step_b)
result.activated_steps  # => [:step_a, :step_b]
```

**Usage in Steps (Router Pattern):**
```ruby
step :router, ->(result) {
  case result.value[:type]
  when :pdf
    result.continue(result.value).activate(:process_pdf)
  when :image
    result.continue(result.value).activate(:process_image)
  else
    result.continue(result.value).activate(:process_default)
  end
}, depends_on: :none

step :process_pdf, ->(r) { ... }, depends_on: :optional
step :process_image, ->(r) { ... }, depends_on: :optional
step :process_default, ->(r) { ... }, depends_on: :optional
```

**Usage in Steps (Soft Failure Pattern):**
```ruby
step :validate, ->(result) {
  if invalid?(result.value)
    # Instead of halting, activate error handlers
    result
      .with_error(:validation, "Invalid input")
      .continue(result.value)
      .activate(:handle_error, :cleanup)
  else
    result.continue(result.value)
  end
}, depends_on: :none

step :handle_error, ->(r) { log_error(r); r.continue(r.value) }, depends_on: :optional
step :cleanup, ->(r) { cleanup(r); r.halt }, depends_on: :optional
```

**Chained Activation:**
```ruby
# Optional steps can activate other optional steps
step :upgrade_to_gold, ->(result) {
  result
    .continue(result.value.merge(tier: :gold))
    .activate(:apply_loyalty_bonus)  # Triggers another optional step
}, depends_on: :optional

step :apply_loyalty_bonus, ->(result) {
  result.continue(result.value.merge(bonus: 1000))
}, depends_on: :optional
```

**Notes:**
- Activation is idempotent (activating the same step twice is safe)
- Activating unknown steps raises `ArgumentError`
- Activating non-optional steps raises `ArgumentError`
- Activated steps preserve through `continue`, `halt`, `with_context`, `with_error`

## Usage Patterns

### Basic Flow Control

```ruby
step ->(result) {
  if valid?(result.value)
    result.continue(result.value)
  else
    result.halt.with_error(:validation, "Invalid")
  end
}
```

### Error Accumulation

```ruby
step ->(result) {
  result_obj = result

  if invalid_email?(result.value[:email])
    result_obj = result_obj.with_error(:email, "Invalid format")
  end

  if invalid_phone?(result.value[:phone])
    result_obj = result_obj.with_error(:phone, "Invalid format")
  end

  # Continue even with errors (check later)
  result_obj.continue(result.value)
}

step ->(result) {
  if result.errors.any?
    result.halt(result.value)
  else
    result.continue(result.value)
  end
}
```

### Context Propagation

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    result
      .with_context(:started_at, Time.now)
      .with_context(:user_id, 123)
      .continue(result.value)
  }

  step ->(result) {
    # Access context from previous step
    user_id = result.context[:user_id]
    data = fetch_user_data(user_id)

    result
      .with_context(:user_data, data)
      .continue(result.value)
  }

  step ->(result) {
    # All context available
    duration = Time.now - result.context[:started_at]

    result
      .with_context(:duration, duration)
      .continue(process(result.value))
  }
end
```

### Combining Operations

```ruby
step ->(result) {
  result
    .with_context(:timestamp, Time.now)
    .with_context(:source, :api)
    .with_error(:warning, "Deprecated API version")
    .continue(transformed_data)
}
```

## Implementation Details

### Immutability

All Result methods return new instances:

```ruby
original = SimpleFlow::Result.new(42)
modified = original.with_context(:key, "value")

original.context  # => {}
modified.context  # => { key: "value" }

# original and modified are different objects
original.object_id != modified.object_id  # => true
```

### Internal State

The Result class maintains internal state that is preserved across method calls:

```ruby
result = SimpleFlow::Result.new(42)
  .halt
  .with_context(:key, "value")

# @continue flag is preserved
result.continue?  # => false
result.context    # => { key: "value" }
```

### Thread Safety

Result objects are immutable and thread-safe. Multiple threads can safely read from the same Result instance.

## Related Documentation

- [Pipeline API](pipeline.md) - How pipelines use Result objects
- [Error Handling Guide](../guides/error-handling.md) - Error handling patterns
- [Validation Patterns](../guides/validation-patterns.md) - Validation strategies
- [Optional Steps Guide](../guides/optional-steps.md) - Dynamic step activation patterns
