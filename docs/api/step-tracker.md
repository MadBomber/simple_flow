# StepTracker API Reference

`StepTracker` wraps a step and, when the step halts the flow, records which step it was in the result's context.

## Class: `SimpleFlow::StepTracker`

**Location**: [`lib/simple_flow/step_tracker.rb`](https://github.com/MadBomber/simple_flow/blob/main/lib/simple_flow/step_tracker.rb)

**Superclass:** `SimpleDelegator`, so the tracker forwards every other method to the wrapped step.

`require "simple_flow"` does not load this class; require it explicitly:

```ruby
require "simple_flow"
require "simple_flow/step_tracker"
```

### Constructor

#### `new(step)`

**Parameters:**
- `step` (Proc/Object) - Any object that responds to `call(result)` and returns a `Result`

### Instance Methods

#### `call(result)`

Calls the wrapped step with `result`. If the returned result can continue, it is returned unchanged. If the step halted, the returned result gets the wrapped step stored under the `:halted_step` context key.

**Parameters:**
- `result` (Result) - The result passed to the step

**Returns:** Result

**Example:**
```ruby
validate = ->(result) do
  if result.value.positive?
    result.continue(result.value)
  else
    result.halt.with_error(:validation, "must be positive")
  end
end

tracked = SimpleFlow::StepTracker.new(validate)

tracked.call(SimpleFlow::Result.new(5)).context
# => {}

halted = tracked.call(SimpleFlow::Result.new(-1))
halted.continue?                          # => false
halted.context[:halted_step].equal?(validate) # => true
```

Wrapping pipeline steps lets you tell which step stopped the flow:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step SimpleFlow::StepTracker.new(validate)
  step SimpleFlow::StepTracker.new(->(result) { result.continue(result.value * 2) })
end

result = pipeline.call(SimpleFlow::Result.new(-1))
result.context[:halted_step] # => the validate lambda
```

## Related Documentation

- [Result API](result.md) - `continue?`, `halt` and `context`
- [Error Handling Guide](../guides/error-handling.md) - Halting and reporting errors
- [Middleware API](middleware.md) - Other ways to wrap steps
