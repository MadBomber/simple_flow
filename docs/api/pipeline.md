# Pipeline API Reference

The `Pipeline` class orchestrates step execution with middleware integration and parallel execution support.

## Class: `SimpleFlow::Pipeline`

**Location**: `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/lib/simple_flow/pipeline.rb`

### Constructor

#### `new(&config)`

Creates a new Pipeline with optional configuration block.

**Parameters:**
- `config` (Block, optional) - Configuration block for defining steps and middleware

**Example:**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging
  step ->(result) { result.continue(result.value + 1) }
end
```

### DSL Methods

#### `use_middleware(middleware, options = {})`

Registers middleware to be applied to each step.

**Parameters:**
- `middleware` (Class/Proc) - Middleware class or proc
- `options` (Hash) - Options passed to middleware constructor

**Example:**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'xyz'
  use_middleware CustomMiddleware, timeout: 30
end
```

#### `step(name_or_callable = nil, callable = nil, depends_on: [], &block)`

Adds a step to the pipeline. Supports named and unnamed steps.

**Parameters:**
- `name_or_callable` (Symbol/Proc/Object) - Step name or callable
- `callable` (Proc/Object) - Callable object (if first param is name)
- `depends_on` (Array) - Dependencies for named steps
- `block` (Block) - Block to use as step

**Returns:** self (for chaining)

**Named Steps:**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, ->(result) { ... }, depends_on: []
  step :process_data, ->(result) { ... }, depends_on: [:fetch_user]
end
```

**Unnamed Steps:**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 1) }
  step { |result| result.continue(result.value * 2) }
end
```

**Class-Based Steps:**
```ruby
class FetchUser
  def call(result)
    user = User.find(result.value)
    result.with_context(:user, user).continue(result.value)
  end
end

pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, FetchUser.new, depends_on: []
end
```

#### `parallel(&block)`

Defines an explicit parallel execution block.

**Parameters:**
- `block` (Block) - Block containing step definitions

**Returns:** self (for chaining)

**Example:**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(validate(result.value)) }

  parallel do
    step ->(result) { result.with_context(:api, fetch_api).continue(result.value) }
    step ->(result) { result.with_context(:db, fetch_db).continue(result.value) }
    step ->(result) { result.with_context(:cache, fetch_cache).continue(result.value) }
  end

  step ->(result) { result.continue(merge_data(result.context)) }
end
```

### Execution Methods

#### `call(result)`

Executes the pipeline sequentially with a given initial result.

**Parameters:**
- `result` (Result) - Initial Result object

**Returns:** Final Result object

**Example:**
```ruby
initial = SimpleFlow::Result.new(5)
result = pipeline.call(initial)

result.value      # => Final value
result.context    # => Accumulated context
result.errors     # => Any errors
result.continue?  # => true/false
```

#### `call_parallel(result, strategy: :auto)`

Executes the pipeline with parallel execution where possible.

**Parameters:**
- `result` (Result) - Initial Result object
- `strategy` (Symbol) - Parallelization strategy (`:auto` or `:explicit`)

**Returns:** Final Result object

**Strategies:**
- `:auto` (default) - Uses dependency graph if named steps exist
- `:explicit` - Only uses explicit parallel blocks

**Example:**
```ruby
# Automatic strategy (uses dependency graph)
result = pipeline.call_parallel(initial_data)

# Explicit strategy
result = pipeline.call_parallel(initial_data, strategy: :explicit)
```

### Visualization Methods

#### `visualize_ascii(show_groups: true)`

Returns ASCII visualization of the dependency graph.

**Parameters:**
- `show_groups` (Boolean) - Whether to show parallel execution groups (default: true)

**Returns:** String (ASCII art) or nil if no named steps

**Example:**
```ruby
puts pipeline.visualize_ascii

# Hide parallel groups
puts pipeline.visualize_ascii(show_groups: false)
```

#### `visualize_dot(include_groups: true, orientation: 'TB')`

Exports dependency graph to Graphviz DOT format.

**Parameters:**
- `include_groups` (Boolean) - Color-code parallel groups (default: true)
- `orientation` (String) - Graph orientation: 'TB' (top-bottom) or 'LR' (left-right)

**Returns:** String (DOT format) or nil if no named steps

**Example:**
```ruby
File.write('pipeline.dot', pipeline.visualize_dot)
# Generate image: dot -Tpng pipeline.dot -o pipeline.png

# Left-to-right layout
File.write('pipeline.dot', pipeline.visualize_dot(orientation: 'LR'))
```

#### `visualize_mermaid()`

Exports dependency graph to Mermaid diagram format.

**Returns:** String (Mermaid format) or nil if no named steps

**Example:**
```ruby
File.write('pipeline.mmd', pipeline.visualize_mermaid)
# View at https://mermaid.live/
```

#### `execution_plan()`

Returns detailed execution plan analysis.

**Returns:** String (execution plan) or nil if no named steps

**Example:**
```ruby
puts pipeline.execution_plan
```

Output includes:
- Total steps and execution phases
- Which steps run in parallel
- Potential speedup vs sequential execution

### Utility Methods

#### `async_available?`

Checks if the async gem is available for true parallel execution.

**Returns:** Boolean

**Example:**
```ruby
if pipeline.async_available?
  puts "Parallel execution enabled"
else
  puts "Falling back to sequential execution"
end
```

#### `dependency_graph`

Returns the dependency graph for this pipeline.

**Returns:** DependencyGraph or nil if no named steps

**Example:**
```ruby
graph = pipeline.dependency_graph
if graph
  puts graph.order            # => [:step1, :step2, :step3]
  puts graph.parallel_order   # => [[:step1], [:step2, :step3]]
end
```

#### `visualize`

Creates a visualizer for this pipeline's dependency graph.

**Returns:** DependencyGraphVisualizer or nil if no named steps

**Example:**
```ruby
visualizer = pipeline.visualize
if visualizer
  puts visualizer.to_ascii
  File.write('graph.dot', visualizer.to_dot)
end
```

### Instance Attributes

#### `steps`

Array of step definitions (read-only).

**Type:** Array

#### `middlewares`

Array of registered middleware (read-only).

**Type:** Array

#### `named_steps`

Hash of named steps (read-only).

**Type:** Hash

#### `step_dependencies`

Hash of step dependencies (read-only).

**Type:** Hash

## Usage Examples

### Basic Sequential Pipeline

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value.strip) }
  step ->(result) { result.continue(result.value.downcase) }
  step ->(result) { result.continue("Hello, #{result.value}!") }
end

result = pipeline.call(SimpleFlow::Result.new("  WORLD  "))
result.value  # => "Hello, world!"
```

### Parallel Pipeline with Dependencies

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, ->(result) {
    user = User.find(result.value)
    result.with_context(:user, user).continue(result.value)
  }, depends_on: []

  step :fetch_orders, ->(result) {
    orders = Order.where(user_id: result.context[:user].id)
    result.with_context(:orders, orders).continue(result.value)
  }, depends_on: [:fetch_user]

  step :fetch_preferences, ->(result) {
    prefs = Preference.where(user_id: result.context[:user].id)
    result.with_context(:preferences, prefs).continue(result.value)
  }, depends_on: [:fetch_user]

  step :build_profile, ->(result) {
    profile = {
      user: result.context[:user],
      orders: result.context[:orders],
      preferences: result.context[:preferences]
    }
    result.continue(profile)
  }, depends_on: [:fetch_orders, :fetch_preferences]
end

# fetch_orders and fetch_preferences run in parallel
result = pipeline.call_parallel(SimpleFlow::Result.new(user_id))
```

### Pipeline with Middleware

```ruby
pipeline = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'demo'

  step ->(result) { result.continue(process(result.value)) }
end
```

### Mixed Execution Styles

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Unnamed sequential step
  step ->(result) { result.continue(sanitize(result.value)) }

  # Named steps with automatic parallelism
  step :step_a, ->(result) { ... }, depends_on: []
  step :step_b, ->(result) { ... }, depends_on: []
  step :step_c, ->(result) { ... }, depends_on: [:step_a, :step_b]

  # Explicit parallel block
  parallel do
    step ->(result) { ... }
    step ->(result) { ... }
  end

  # Another sequential step
  step ->(result) { result.continue(finalize(result.value)) }
end
```

## Related Documentation

- [Result API](result.md) - Result class reference
- [Parallel Steps Guide](../concurrent/parallel-steps.md) - Using named steps
- [Middleware API](middleware.md) - Middleware reference
- [Performance Guide](../concurrent/performance.md) - Optimization strategies
