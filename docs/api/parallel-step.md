# Parallel Execution API Reference

This document covers the APIs for parallel execution in SimpleFlow, including the ParallelExecutor class and dependency graph management.

## Class: `SimpleFlow::ParallelExecutor`

**Location**: `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/lib/simple_flow/parallel_executor.rb`

Handles parallel execution of steps using the async gem, with automatic fallback to sequential execution.

### Class Methods

#### `execute_parallel(steps, result, concurrency: :auto, max_concurrent: nil)`

Executes a group of steps in parallel.

**Parameters:**
- `steps` (Array<Proc>) - Array of callable steps
- `result` (Result) - The input result to pass to each step
- `concurrency` (Symbol) - Concurrency model (`:auto`, `:threads`, or `:async`)
- `max_concurrent` (Integer, nil) - Maximum number of fibers to run simultaneously (async only; `nil` means unlimited)

**Returns:** Array<Result> - Results from each step

**Behavior:**
- Uses async gem for true parallel execution if available
- Falls back to Ruby threads if async is not available
- Each step receives the same input result
- Returns array of results in same order as input steps
- When `max_concurrent:` is set and async is in use, an `Async::Semaphore` gates fiber spawning so at most `max_concurrent` fibers run at once
- `max_concurrent:` is silently ignored when the thread fallback is active

**Example:**
```ruby
steps = [
  ->(result) { result.with_context(:a, "data_a").continue(result.value) },
  ->(result) { result.with_context(:b, "data_b").continue(result.value) },
  ->(result) { result.with_context(:c, "data_c").continue(result.value) }
]

initial = SimpleFlow::Result.new(123)

# Unlimited concurrency (default)
results = SimpleFlow::ParallelExecutor.execute_parallel(steps, initial)

# Cap at 2 simultaneous fibers
results = SimpleFlow::ParallelExecutor.execute_parallel(steps, initial, max_concurrent: 2)

results.size  # => 3
results[0].context[:a]  # => "data_a"
results[1].context[:b]  # => "data_b"
results[2].context[:c]  # => "data_c"
```

#### `execute_sequential(steps, result)`

Executes steps sequentially (fallback implementation).

**Parameters:**
- `steps` (Array<Proc>) - Array of callable steps
- `result` (Result) - The input result

**Returns:** Array<Result>

**Example:**
```ruby
results = SimpleFlow::ParallelExecutor.execute_sequential(steps, initial)
```

#### `async_available?`

Checks if the async gem is available.

**Returns:** Boolean

**Example:**
```ruby
if SimpleFlow::ParallelExecutor.async_available?
  puts "Async gem is installed - true parallel execution enabled"
else
  puts "Async gem not found - will use sequential fallback"
end
```

### Implementation Details

#### Async Integration

When the async gem is available, all steps are run as fibers inside a single `Async` block. An optional `Async::Semaphore` gates the barrier when `max_concurrent:` is set:

```ruby
# Unlimited (default)
Async do
  barrier = Async::Barrier.new
  tasks = steps.map { |step| barrier.async { step.call(result) } }
  barrier.wait
  tasks.map(&:result)
end

# With cap — semaphore becomes the barrier's parent
Async do
  semaphore = Async::Semaphore.new(max_concurrent)
  barrier   = Async::Barrier.new(parent: semaphore)
  tasks = steps.map { |step| barrier.async { step.call(result) } }
  barrier.wait
  tasks.map(&:result)
end
```

#### Thread Fallback

When async is not available, steps run as Ruby threads. `max_concurrent:` is not applied in this path:

```ruby
threads = steps.map { |step| Thread.new { step.call(result) } }
threads.map(&:value)
```

## Class: `SimpleFlow::DependencyGraph`

**Location**: `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/lib/simple_flow/dependency_graph.rb`

Manages dependencies between pipeline steps and determines which steps can execute in parallel.

### Constructor

#### `new(dependencies)`

Creates a new dependency graph.

**Parameters:**
- `dependencies` (Hash) - Hash mapping step names to their dependencies

**Example:**
```ruby
graph = SimpleFlow::DependencyGraph.new(
  fetch_user: [],
  fetch_orders: [:fetch_user],
  fetch_products: [:fetch_user],
  calculate_total: [:fetch_orders, :fetch_products]
)
```

### Instance Methods

#### `order`

Returns steps in topological order (dependencies first).

**Returns:** Array - Ordered list of step names

**Example:**
```ruby
graph.order
# => [:fetch_user, :fetch_orders, :fetch_products, :calculate_total]
```

#### `reverse_order`

Returns steps in reverse topological order.

**Returns:** Array

**Example:**
```ruby
graph.reverse_order
# => [:calculate_total, :fetch_products, :fetch_orders, :fetch_user]
```

#### `parallel_order`

Groups steps that can be executed in parallel.

**Returns:** Array<Array> - Array of groups, where each group can run in parallel

**Algorithm:**
Steps can run in parallel if:
1. They have the exact same dependencies, OR
2. All of a step's dependencies have been resolved in previous groups

**Example:**
```ruby
graph = SimpleFlow::DependencyGraph.new(
  step_a: [],
  step_b: [:step_a],
  step_c: [:step_a],
  step_d: [:step_b, :step_c]
)

graph.parallel_order
# => [
#      [:step_a],           # Group 1: step_a (no dependencies)
#      [:step_b, :step_c],  # Group 2: parallel (both depend only on step_a)
#      [:step_d]            # Group 3: step_d (waits for step_b and step_c)
#    ]
```

#### `subgraph(node)`

Generates a subgraph starting at the given node.

**Parameters:**
- `node` (Symbol) - The starting node

**Returns:** DependencyGraph - New graph containing only the node and its dependencies

**Example:**
```ruby
graph = SimpleFlow::DependencyGraph.new(
  step_a: [],
  step_b: [:step_a],
  step_c: [:step_b]
)

subgraph = graph.subgraph(:step_c)
subgraph.dependencies
# => { step_c: [:step_b], step_b: [:step_a], step_a: [] }
```

#### `merge(other)`

Merges this graph with another graph.

**Parameters:**
- `other` (DependencyGraph) - Another dependency graph

**Returns:** DependencyGraph - New merged graph

**Behavior:**
- Combines all dependencies from both graphs
- If both graphs depend on the same item, uses the union of dependencies

**Example:**
```ruby
graph1 = SimpleFlow::DependencyGraph.new(
  step_a: [],
  step_b: [:step_a]
)

graph2 = SimpleFlow::DependencyGraph.new(
  step_c: [],
  step_b: [:step_c]  # Different dependency for step_b
)

merged = graph1.merge(graph2)
merged.dependencies[:step_b]
# => [:step_a, :step_c]  # Union of dependencies
```

### Instance Attributes

#### `dependencies`

Hash of dependencies (read-only).

**Type:** Hash

**Example:**
```ruby
graph.dependencies
# => {
#      fetch_user: [],
#      fetch_orders: [:fetch_user],
#      fetch_products: [:fetch_user],
#      calculate_total: [:fetch_orders, :fetch_products]
#    }
```

## Class: `SimpleFlow::Pipeline::ParallelBlock`

Internal helper class for building parallel blocks.

### Methods

#### `step(name_or_callable = nil, callable = nil, depends_on: [], &block)`

Adds a step to the parallel block.

**Note:** This is used internally by the Pipeline DSL.

## Usage Examples

### Direct ParallelExecutor Usage

```ruby
steps = [
  ->(result) {
    data = fetch_from_api_a(result.value)
    result.with_context(:api_a, data).continue(result.value)
  },
  ->(result) {
    data = fetch_from_api_b(result.value)
    result.with_context(:api_b, data).continue(result.value)
  },
  ->(result) {
    data = fetch_from_cache(result.value)
    result.with_context(:cache, data).continue(result.value)
  }
]

initial = SimpleFlow::Result.new(request_id)
results = SimpleFlow::ParallelExecutor.execute_parallel(steps, initial)

# Merge contexts
merged_context = results.reduce({}) do |acc, r|
  acc.merge(r.context)
end
# => { api_a: ..., api_b: ..., cache: ... }
```

### Dependency Graph Analysis

```ruby
# Define dependencies
dependencies = {
  validate_input: [],
  check_inventory: [:validate_input],
  check_pricing: [:validate_input],
  check_shipping: [:validate_input],
  calculate_discount: [:check_inventory, :check_pricing],
  finalize_order: [:calculate_discount, :check_shipping]
}

graph = SimpleFlow::DependencyGraph.new(dependencies)

# Analyze execution order
puts "Sequential order:"
puts graph.order.join(' -> ')
# => validate_input -> check_inventory -> check_pricing -> check_shipping -> calculate_discount -> finalize_order

puts "\nParallel execution groups:"
graph.parallel_order.each_with_index do |group, index|
  puts "Group #{index + 1}: #{group.join(', ')}"
end
# => Group 1: validate_input
# => Group 2: check_inventory, check_pricing, check_shipping
# => Group 3: calculate_discount
# => Group 4: finalize_order

# Calculate potential speedup
total_steps = graph.order.size
total_groups = graph.parallel_order.size
puts "\nPotential speedup: #{total_steps.to_f / total_groups}x"
# => Potential speedup: 1.5x
```

### Installing Async Gem

Add to your Gemfile:
```ruby
gem 'async', '~> 2.0'
```

Then run:
```bash
bundle install
```

### Checking Async Availability

```ruby
# In your application
if SimpleFlow::ParallelExecutor.async_available?
  puts "Parallel execution enabled"
  puts "Using async gem for true concurrency"
else
  puts "Parallel execution disabled"
  puts "Add 'async' gem to Gemfile for parallel support"
end
```

## Related Documentation

- [Pipeline API](pipeline.md) - Pipeline class reference
- [Parallel Steps Guide](../concurrent/parallel-steps.md) - Using parallel execution
- [Performance Guide](../concurrent/performance.md) - Performance characteristics
- [Best Practices](../concurrent/best-practices.md) - Concurrent execution best practices
