# Parallel Execution with Named Steps

SimpleFlow provides powerful parallel execution capabilities through two approaches: automatic parallel discovery using dependency graphs and explicit parallel blocks. This guide focuses on using named steps with dependencies for automatic parallelization.

## Overview

When you define steps with names and dependencies, SimpleFlow automatically analyzes the dependency graph and executes independent steps concurrently. This provides optimal performance without requiring you to explicitly manage parallelism.

## Basic Concepts

### Named Steps

A named step is defined with three components:

1. **Name** (Symbol) - Unique identifier for the step
2. **Callable** (Proc/Lambda) - The code to execute
3. **Dependencies** (Array of Symbols) - Steps that must complete first

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :step_name, ->(result) {
    # Your code here
    result.continue(new_value)
  }, depends_on: [:prerequisite_step]
end
```

### Dependency Declaration

Dependencies are declared using the `depends_on:` parameter:

```ruby
# No dependencies - can run immediately
step :initial_step, ->(result) { ... }, depends_on: []

# Depends on one step
step :second_step, ->(result) { ... }, depends_on: [:initial_step]

# Depends on multiple steps
step :final_step, ->(result) { ... }, depends_on: [:second_step, :third_step]
```

## Automatic Parallelization

### How It Works

1. **Graph Analysis**: SimpleFlow builds a dependency graph from your step declarations
2. **Topological Sort**: Steps are organized into execution groups using Ruby's TSort module
3. **Parallel Execution**: Steps with all dependencies satisfied run concurrently
4. **Result Merging**: Contexts and errors from parallel steps are automatically merged

### Simple Example

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Step 1: Runs first (no dependencies)
  step :fetch_user, ->(result) {
    user = UserService.find(result.value)
    result.with_context(:user, user).continue(result.value)
  }, depends_on: []

  # Steps 2 & 3: Run in parallel (both depend only on step 1)
  step :fetch_orders, ->(result) {
    orders = OrderService.for_user(result.context[:user])
    result.with_context(:orders, orders).continue(result.value)
  }, depends_on: [:fetch_user]

  step :fetch_preferences, ->(result) {
    prefs = PreferenceService.for_user(result.context[:user])
    result.with_context(:preferences, prefs).continue(result.value)
  }, depends_on: [:fetch_user]

  # Step 4: Runs after both parallel steps complete
  step :build_profile, ->(result) {
    profile = {
      user: result.context[:user],
      orders: result.context[:orders],
      preferences: result.context[:preferences]
    }
    result.continue(profile)
  }, depends_on: [:fetch_orders, :fetch_preferences]
end

# Execute with automatic parallelism
result = pipeline.call_parallel(SimpleFlow::Result.new(user_id))
```

**Execution Flow:**
1. `fetch_user` runs first
2. `fetch_orders` and `fetch_preferences` run in parallel
3. `build_profile` runs after both parallel steps complete

## Complex Dependency Graphs

### Multi-Level Parallelism

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Level 1: Validation (sequential)
  step :validate_input, ->(result) {
    # Validate request
    result.with_context(:validated, true).continue(result.value)
  }, depends_on: []

  # Level 2: Three independent checks (parallel)
  step :check_inventory, ->(result) {
    inventory = InventoryService.check(result.value)
    result.with_context(:inventory, inventory).continue(result.value)
  }, depends_on: [:validate_input]

  step :check_pricing, ->(result) {
    price = PricingService.calculate(result.value)
    result.with_context(:price, price).continue(result.value)
  }, depends_on: [:validate_input]

  step :check_shipping, ->(result) {
    shipping = ShippingService.calculate(result.value)
    result.with_context(:shipping, shipping).continue(result.value)
  }, depends_on: [:validate_input]

  # Level 3: Calculate discount (depends on inventory and pricing)
  step :calculate_discount, ->(result) {
    discount = DiscountService.calculate(
      result.context[:inventory],
      result.context[:price]
    )
    result.with_context(:discount, discount).continue(result.value)
  }, depends_on: [:check_inventory, :check_pricing]

  # Level 4: Finalize (depends on discount and shipping)
  step :finalize_order, ->(result) {
    total = result.context[:price] +
            result.context[:shipping] -
            result.context[:discount]
    result.continue(total)
  }, depends_on: [:calculate_discount, :check_shipping]
end
```

**Execution Groups:**
- Group 1: `validate_input` (sequential)
- Group 2: `check_inventory`, `check_pricing`, `check_shipping` (parallel)
- Group 3: `calculate_discount` (sequential, waits for inventory and pricing)
- Group 4: `finalize_order` (sequential, waits for discount and shipping)

## Context Merging

When parallel steps complete, SimpleFlow automatically merges their contexts and errors:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :task_a, ->(result) {
    result.with_context(:data_a, "from A").continue(result.value)
  }, depends_on: []

  step :task_b, ->(result) {
    result.with_context(:data_b, "from B").continue(result.value)
  }, depends_on: []

  step :combine, ->(result) {
    # Both contexts are available
    combined = {
      a: result.context[:data_a],  # "from A"
      b: result.context[:data_b]   # "from B"
    }
    result.continue(combined)
  }, depends_on: [:task_a, :task_b]
end
```

### Error Accumulation

Errors from parallel steps are also merged:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :validate_email, ->(result) {
    if invalid_email?(result.value[:email])
      result.with_error(:email, "Invalid format")
    end
    result.continue(result.value)
  }, depends_on: []

  step :validate_phone, ->(result) {
    if invalid_phone?(result.value[:phone])
      result.with_error(:phone, "Invalid format")
    end
    result.continue(result.value)
  }, depends_on: []

  step :check_errors, ->(result) {
    # Errors from both parallel validations are available
    if result.errors.any?
      result.halt(result.value)  # Stop if any validation failed
    else
      result.continue(result.value)
    end
  }, depends_on: [:validate_email, :validate_phone]
end
```

## Halting Execution

If any parallel step calls `halt()`, the pipeline stops immediately:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :task_a, ->(result) {
    result.with_context(:success_a, true).continue(result.value)
  }, depends_on: []

  step :task_b, ->(result) {
    # This step fails
    result.halt.with_error(:failure, "Task B failed")
  }, depends_on: []

  step :task_c, ->(result) {
    result.with_context(:success_c, true).continue(result.value)
  }, depends_on: []

  step :final_step, ->(result) {
    # This will NOT execute because task_b halted
    result.continue("Completed")
  }, depends_on: [:task_a, :task_b, :task_c]
end

result = pipeline.call_parallel(initial_data)
# result.continue? => false
# result.errors => {:failure => ["Task B failed"]}
```

## Execution Methods

### `call_parallel(result, strategy: :auto)`

Executes the pipeline with parallel support:

```ruby
# Automatic strategy (default) - uses dependency graph if named steps exist
result = pipeline.call_parallel(initial_result)

# Automatic strategy (explicit)
result = pipeline.call_parallel(initial_result, strategy: :auto)

# Explicit strategy - only uses explicit parallel blocks
result = pipeline.call_parallel(initial_result, strategy: :explicit)
```

### `call(result)`

Executes sequentially (ignores parallelism):

```ruby
# Sequential execution - useful for debugging
result = pipeline.call(initial_result)
```

## Visualizing Dependencies

### ASCII Visualization

```ruby
# Print dependency graph to console
puts pipeline.visualize_ascii

# Hide parallel groups
puts pipeline.visualize_ascii(show_groups: false)
```

### Graphviz DOT Format

```ruby
# Generate DOT file for visualization
dot_content = pipeline.visualize_dot
File.write('pipeline.dot', dot_content)

# Generate image: dot -Tpng pipeline.dot -o pipeline.png

# Left-to-right orientation
dot_content = pipeline.visualize_dot(orientation: 'LR')
```

### Mermaid Diagrams

```ruby
# Generate Mermaid diagram
mermaid = pipeline.visualize_mermaid
File.write('pipeline.mmd', mermaid)

# View at https://mermaid.live/
```

### Execution Plan

```ruby
# Get detailed execution analysis
puts pipeline.execution_plan
```

Output includes:
- Total steps and execution phases
- Which steps run in parallel
- Potential speedup vs sequential execution
- Step-by-step execution order

## Best Practices

### 1. Design Independent Steps

Ensure parallel steps are truly independent:

```ruby
# GOOD: Independent operations
step :fetch_user_data, ->(result) { ... }, depends_on: []
step :fetch_product_data, ->(result) { ... }, depends_on: []

# BAD: Steps that modify shared state
step :increment_counter, ->(result) { @counter += 1; ... }, depends_on: []
step :read_counter, ->(result) { puts @counter; ... }, depends_on: []
```

### 2. Use Context for Data Sharing

Pass data between steps using context, not instance variables:

```ruby
# GOOD: Using context
step :fetch_data, ->(result) {
  data = API.fetch(result.value)
  result.with_context(:api_data, data).continue(result.value)
}, depends_on: []

step :process_data, ->(result) {
  processed = transform(result.context[:api_data])
  result.continue(processed)
}, depends_on: [:fetch_data]

# BAD: Using instance variables
@shared_data = nil
step :fetch_data, ->(result) {
  @shared_data = API.fetch(result.value)  # Race condition!
  result.continue(result.value)
}, depends_on: []
```

### 3. Declare All Dependencies

Be explicit about dependencies to ensure correct execution order:

```ruby
# GOOD: Clear dependencies
step :load_config, ->(result) { ... }, depends_on: []
step :validate_config, ->(result) { ... }, depends_on: [:load_config]
step :apply_config, ->(result) { ... }, depends_on: [:validate_config]

# BAD: Missing dependencies
step :load_config, ->(result) { ... }, depends_on: []
step :apply_config, ->(result) { ... }, depends_on: []  # Should depend on load_config!
```

### 4. Keep Steps Focused

Each step should have a single responsibility:

```ruby
# GOOD: Focused steps
step :fetch_user, ->(result) { ... }, depends_on: []
step :fetch_orders, ->(result) { ... }, depends_on: [:fetch_user]
step :calculate_total, ->(result) { ... }, depends_on: [:fetch_orders]

# BAD: Monolithic step
step :do_everything, ->(result) {
  user = fetch_user
  orders = fetch_orders(user)
  total = calculate_total(orders)
  # Too much in one step!
}, depends_on: []
```

### 5. Handle Errors Gracefully

Add error handling at appropriate points:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Parallel data fetching
  step :fetch_a, ->(result) { ... }, depends_on: []
  step :fetch_b, ->(result) { ... }, depends_on: []

  # Check for errors before proceeding
  step :validate_fetch, ->(result) {
    if result.errors.any?
      result.halt.with_error(:fetch, "Failed to fetch required data")
    else
      result.continue(result.value)
    end
  }, depends_on: [:fetch_a, :fetch_b]

  # Only runs if validation passes
  step :process, ->(result) { ... }, depends_on: [:validate_fetch]
end
```

## Real-World Example

See `/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/examples/06_real_world_ecommerce.rb` for a complete e-commerce order processing pipeline that demonstrates:

- Multi-level parallel execution
- Context merging
- Error handling
- Complex dependency relationships

## Related Documentation

- [Performance Characteristics](performance.md) - Understanding parallel execution performance
- [Best Practices](best-practices.md) - Comprehensive best practices for concurrent execution
- [Pipeline API](../api/pipeline.md) - Complete Pipeline API reference
- [Parallel Executor API](../api/parallel-step.md) - Low-level parallel execution details
