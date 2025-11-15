# Pipeline

The `Pipeline` class is the orchestrator that manages the execution of steps in your data processing workflow.

## Overview

A Pipeline defines a sequence of operations (steps) that transform data, with support for:

- Sequential execution
- Parallel execution (automatic and explicit)
- Middleware integration
- Short-circuit evaluation
- Dependency management

## Basic Usage

```ruby
require 'simple_flow'

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value * 2) }
  step ->(result) { result.continue(result.value + 10) }
  step ->(result) { result.continue(result.value.to_s) }
end

result = pipeline.call(SimpleFlow::Result.new(5))
result.value # => "20"
```

## Defining Steps

### Lambda Steps

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) do
    # Process the result
    new_value = transform(result.value)
    result.continue(new_value)
  end
end
```

### Method Steps

```ruby
def validate_user(result)
  if result.value[:email].present?
    result.continue(result.value)
  else
    result.with_error(:validation, 'Email required').halt
  end
end

pipeline = SimpleFlow::Pipeline.new do
  step method(:validate_user)
end
```

### Callable Objects

```ruby
class EmailValidator
  def call(result)
    # Validation logic
    result.continue(result.value)
  end
end

pipeline = SimpleFlow::Pipeline.new do
  step EmailValidator.new
end
```

## Named Steps with Dependencies

For parallel execution, you can define named steps with explicit dependencies:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :validate, ->(result) { validate(result) }, depends_on: []
  step :fetch_user, ->(result) { fetch_user(result) }, depends_on: [:validate]
  step :fetch_orders, ->(result) { fetch_orders(result) }, depends_on: [:validate]
  step :calculate, ->(result) { calculate(result) }, depends_on: [:fetch_user, :fetch_orders]
end
```

Steps with the same satisfied dependencies run in parallel automatically.

## Parallel Execution

### Automatic Parallelization

```ruby
# These will run in parallel (both depend only on :validate)
pipeline = SimpleFlow::Pipeline.new do
  step :validate, validator, depends_on: []
  step :fetch_orders, fetch_orders_callable, depends_on: [:validate]
  step :fetch_products, fetch_products_callable, depends_on: [:validate]
end

result = pipeline.call_parallel(initial_result)
```

### Explicit Parallel Blocks

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Sequential step
  step ->(result) { validate(result) }

  # These run in parallel
  parallel do
    step ->(result) { fetch_from_api(result) }
    step ->(result) { fetch_from_cache(result) }
    step ->(result) { fetch_from_database(result) }
  end

  # Sequential step
  step ->(result) { merge_results(result) }
end
```

## Short-Circuit Evaluation

Pipelines automatically stop executing when a step halts:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue("step 1") }
  step ->(result) { result.halt("stopped") }        # Execution stops here
  step ->(result) { result.continue("step 3") }     # Not executed
end

result = pipeline.call(SimpleFlow::Result.new(nil))
result.value      # => "stopped"
result.continue?  # => false
```

## Middleware

Apply cross-cutting concerns using middleware:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use SimpleFlow::Middleware::Logging
  use SimpleFlow::Middleware::Instrumentation, api_key: 'my-key'

  step ->(result) { process(result) }
end
```

[Learn more about Middleware](middleware.md)

## Visualization

Pipelines with named steps can be visualized:

```ruby
# Generate ASCII visualization
puts pipeline.visualize_ascii

# Export to Graphviz DOT format
File.write('pipeline.dot', pipeline.visualize_dot)

# Export to Mermaid diagram
File.write('pipeline.mmd', pipeline.visualize_mermaid)

# Get execution plan analysis
puts pipeline.execution_plan
```

## API Reference

### Class Methods

| Method | Description |
|--------|-------------|
| `new(&block)` | Create a new pipeline with DSL block |

### Instance Methods

| Method | Description |
|--------|-------------|
| `call(result)` | Execute pipeline sequentially |
| `call_parallel(result, strategy: :auto)` | Execute with parallelization |
| `dependency_graph` | Get underlying dependency graph |
| `visualize` | Get visualizer instance |
| `visualize_ascii(show_groups: true)` | ASCII visualization |
| `visualize_dot(include_groups: true, orientation: 'TB')` | Graphviz DOT export |
| `visualize_mermaid` | Mermaid diagram export |
| `execution_plan` | Performance analysis |

### DSL Methods (in Pipeline.new block)

| Method | Description |
|--------|-------------|
| `step(callable)` | Add anonymous step |
| `step(name, callable, depends_on: [])` | Add named step with dependencies |
| `parallel(&block)` | Define explicit parallel block |
| `use(middleware, **options)` | Add middleware |

## Best Practices

1. **Keep steps focused**: Each step should do one thing well
2. **Use meaningful names**: Named steps improve visualization and debugging
3. **Handle errors gracefully**: Use `.halt` to stop processing on errors
4. **Leverage context**: Pass metadata between steps via `result.context`
5. **Consider parallelization**: Use named steps with dependencies for I/O-bound operations
6. **Apply middleware judiciously**: Add logging/instrumentation for observability

## Example: E-Commerce Order Processing

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use SimpleFlow::Middleware::Logging
  use SimpleFlow::Middleware::Instrumentation

  step :validate, ->(result) {
    # Validate order
    result.continue(result.value)
  }, depends_on: []

  step :check_inventory, ->(result) {
    # Check stock
    result.continue(result.value)
  }, depends_on: [:validate]

  step :calculate_shipping, ->(result) {
    # Calculate shipping cost
    result.continue(result.value)
  }, depends_on: [:validate]

  step :process_payment, ->(result) {
    # Process payment
    result.continue(result.value)
  }, depends_on: [:check_inventory, :calculate_shipping]

  step :send_confirmation, ->(result) {
    # Send email
    result.continue(result.value)
  }, depends_on: [:process_payment]
end
```

## Next Steps

- [Steps](steps.md) - Deep dive into step implementations
- [Middleware](middleware.md) - Adding cross-cutting concerns
- [Parallel Execution](../concurrent/parallel-steps.md) - Concurrent processing patterns
- [Complex Workflows Guide](../guides/complex-workflows.md) - Real-world examples
