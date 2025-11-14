# Dagwood Concepts Analysis

## Overview

[Dagwood](https://github.com/MadBomber/dagwood) is a Ruby gem for dependency graph analysis and resolution ordering using topologically sorted directed acyclic graphs (DAGs).

## Key Dagwood Concepts

### 1. Dependency Declaration

Dagwood explicitly declares dependencies between tasks:

```ruby
graph = Dagwood::DependencyGraph.new(
  add_mustard: [:slice_bread],
  add_smoked_meat: [:slice_bread],
  close_sandwich: [:add_mustard, :add_smoked_meat]
)
```

### 2. Automatic Parallel Detection

The `parallel_order` method **automatically groups** tasks that can run concurrently:

```ruby
graph.parallel_order
# => [[:slice_bread], [:add_mustard, :add_smoked_meat], [:close_sandwich]]
```

Tasks in the same nested array can run in parallel because they have the same dependencies.

### 3. Serial Ordering

The `order` method provides topologically sorted execution order:

```ruby
graph.order
# => [:slice_bread, :add_mustard, :add_smoked_meat, :close_sandwich]
```

### 4. Reverse Ordering

The `reverse_order` method enables teardown/cleanup operations:

```ruby
graph.reverse_order
# => [:close_sandwich, :add_smoked_meat, :add_mustard, :slice_bread]
```

### 5. Subgraphs

Extract dependency chains for specific nodes:

```ruby
subgraph = graph.subgraph(:add_mustard)
subgraph.order
# => [:slice_bread, :add_mustard]
```

### 6. Graph Merging

Combine multiple dependency graphs:

```ruby
ultimate_recipe = recipe1.merge(recipe2)
```

## Potential Improvements for SimpleFlow

### 1. ⭐ Automatic Parallel Detection (High Value)

**Current SimpleFlow (Manual):**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { fetch_user(result) }

  # User must manually identify parallel steps
  parallel do
    step ->(result) { fetch_orders(result) }
    step ->(result) { fetch_preferences(result) }
  end
end
```

**With Dagwood Concepts (Automatic):**
```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user
  step :fetch_orders, depends_on: [:fetch_user]
  step :fetch_preferences, depends_on: [:fetch_user]
  step :fetch_analytics  # No dependencies, runs first
  step :aggregate, depends_on: [:fetch_orders, :fetch_preferences]
end

# Pipeline automatically determines:
# Level 0: [:fetch_analytics, :fetch_user] (parallel)
# Level 1: [:fetch_orders, :fetch_preferences] (parallel)
# Level 2: [:aggregate]
```

**Benefits:**
- No manual `parallel` blocks needed
- Automatic optimization
- Clearer dependency relationships
- Easier to maintain

### 2. ⭐ Pipeline Composition (High Value)

**Merge Multiple Pipelines:**
```ruby
user_flow = SimpleFlow::Pipeline.new do
  step :fetch_user
  step :validate_user, depends_on: [:fetch_user]
end

order_flow = SimpleFlow::Pipeline.new do
  step :fetch_orders
  step :calculate_total, depends_on: [:fetch_orders]
end

# Merge pipelines
combined = user_flow.merge(order_flow)
combined.parallel_order
# Automatically detects:
# Level 0: [:fetch_user, :fetch_orders] (parallel)
# Level 1: [:validate_user, :calculate_total] (parallel)
```

**Benefits:**
- Reusable pipeline components
- Compose complex workflows from simple ones
- Better modularity

### 3. Reverse/Cleanup Pipelines (Medium Value)

**Automatic Teardown:**
```ruby
setup_pipeline = SimpleFlow::Pipeline.new do
  step :create_temp_files
  step :connect_database, depends_on: [:create_temp_files]
  step :load_data, depends_on: [:connect_database]
end

# Automatically generate cleanup
cleanup_pipeline = setup_pipeline.reverse
# Executes: [:load_data, :connect_database, :create_temp_files] in reverse
```

**Benefits:**
- Transaction rollback
- Resource cleanup
- Error recovery

### 4. Subgraph Extraction (Medium Value)

**Partial Pipeline Execution:**
```ruby
full_pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user
  step :fetch_orders, depends_on: [:fetch_user]
  step :fetch_preferences, depends_on: [:fetch_user]
  step :calculate_total, depends_on: [:fetch_orders]
  step :apply_discount, depends_on: [:calculate_total, :fetch_preferences]
end

# Extract only what's needed for calculate_total
partial = full_pipeline.subgraph(:calculate_total)
# Includes: [:fetch_user, :fetch_orders, :calculate_total]
# Excludes: [:fetch_preferences, :apply_discount]
```

**Benefits:**
- Run only necessary steps
- Better performance
- Easier testing

### 5. Named Steps with Dependency DSL (High Value)

**Better than Anonymous Lambdas:**
```ruby
class UserPipeline < SimpleFlow::Pipeline
  define do
    step :validate_input

    step :fetch_user, depends_on: [:validate_input]
    step :fetch_orders, depends_on: [:fetch_user]
    step :fetch_preferences, depends_on: [:fetch_user]

    step :enrich_user_data, depends_on: [
      :fetch_user,
      :fetch_orders,
      :fetch_preferences
    ]
  end

  def validate_input(result)
    # Implementation
    result.continue(result.value)
  end

  def fetch_user(result)
    # Implementation
  end

  # ... other step methods
end
```

**Benefits:**
- Better debugging (named methods vs lambdas)
- Easier testing (test individual methods)
- Clear dependency visualization
- Self-documenting code

## Implementation Proposal

### Phase 1: Add Dependency Tracking

```ruby
# lib/simple_flow/dependency_graph.rb
require 'dagwood'

module SimpleFlow
  class DependencyGraph
    def initialize
      @steps = {}
      @dependencies = {}
    end

    def add_step(name, callable, depends_on: [])
      @steps[name] = callable
      @dependencies[name] = depends_on
    end

    def parallel_order
      graph = Dagwood::DependencyGraph.new(@dependencies)
      graph.parallel_order
    end

    def execute(initial_result)
      parallel_order.each do |level|
        if level.length == 1
          # Sequential step
          step_name = level.first
          initial_result = @steps[step_name].call(initial_result)
        else
          # Parallel steps
          parallel_step = ParallelStep.new(level.map { |name| @steps[name] })
          initial_result = parallel_step.call(initial_result)
        end

        break unless initial_result.continue?
      end

      initial_result
    end
  end
end
```

### Phase 2: Enhanced Pipeline DSL

```ruby
# lib/simple_flow/pipeline.rb (enhanced)
module SimpleFlow
  class Pipeline
    def initialize(&config)
      @dependency_graph = DependencyGraph.new
      @steps = []
      @middlewares = []
      instance_eval(&config) if block_given?
    end

    # New: Named step with dependencies
    def step(name = nil, depends_on: [], &block)
      if name.is_a?(Symbol)
        # Named step with dependencies
        callable = block || method(name)
        @dependency_graph.add_step(name, callable, depends_on: depends_on)
      else
        # Original anonymous step behavior (backward compatible)
        callable = name || block
        @steps << apply_middleware(callable)
      end
      self
    end

    def call(result)
      if @dependency_graph.has_steps?
        # Use automatic parallel detection
        @dependency_graph.execute(result)
      else
        # Use original sequential/manual parallel execution
        @steps.reduce(result) do |res, step|
          res.respond_to?(:continue?) && !res.continue? ? res : step.call(res)
        end
      end
    end
  end
end
```

### Phase 3: Pipeline Composition

```ruby
# lib/simple_flow/pipeline.rb (enhanced)
class Pipeline
  def merge(other_pipeline)
    merged = Pipeline.new
    merged.dependency_graph = @dependency_graph.merge(other_pipeline.dependency_graph)
    merged
  end

  def reverse
    reversed = Pipeline.new
    reversed.dependency_graph = @dependency_graph.reverse
    reversed
  end

  def subgraph(step_name)
    partial = Pipeline.new
    partial.dependency_graph = @dependency_graph.subgraph(step_name)
    partial
  end
end
```

## Usage Examples

### Example 1: Automatic Parallelization

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user
  step :fetch_orders, depends_on: [:fetch_user]
  step :fetch_preferences, depends_on: [:fetch_user]
  step :fetch_analytics, depends_on: [:fetch_user]
  step :aggregate, depends_on: [:fetch_orders, :fetch_preferences, :fetch_analytics]
end

# Automatically executes as:
# Level 0: fetch_user
# Level 1: fetch_orders, fetch_preferences, fetch_analytics (parallel)
# Level 2: aggregate
```

### Example 2: Pipeline Composition

```ruby
base_validation = SimpleFlow::Pipeline.new do
  step :validate_email
  step :validate_password
end

user_creation = SimpleFlow::Pipeline.new do
  step :create_user, depends_on: [:validate_email, :validate_password]
  step :send_welcome_email, depends_on: [:create_user]
end

full_flow = base_validation.merge(user_creation)
```

### Example 3: Cleanup Pipeline

```ruby
setup = SimpleFlow::Pipeline.new do
  step :allocate_resources
  step :create_connection, depends_on: [:allocate_resources]
  step :initialize_state, depends_on: [:create_connection]
end

# Automatic cleanup in reverse order
cleanup = setup.reverse
```

## Backward Compatibility

All enhancements maintain backward compatibility:

```ruby
# Old style still works
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { ... }
  parallel do
    step ->(result) { ... }
    step ->(result) { ... }
  end
end

# New style with dependencies
pipeline = SimpleFlow::Pipeline.new do
  step :task1
  step :task2, depends_on: [:task1]
end

# Mixed (both work together)
pipeline = SimpleFlow::Pipeline.new do
  step :named_task
  step ->(result) { ... }  # Anonymous still works
end
```

## Recommendations

### High Priority
1. **Dependency tracking and automatic parallelization** - Biggest value add
2. **Named steps DSL** - Better debugging and testing
3. **Pipeline composition** - Better code reuse

### Medium Priority
4. **Reverse pipelines** - Useful for cleanup
5. **Subgraph extraction** - Useful for testing

### Low Priority
6. **Complex dependency visualization** - Nice to have

## Next Steps

1. Add `dagwood` as a dependency
2. Implement `SimpleFlow::DependencyGraph` wrapper
3. Enhance `Pipeline` DSL with named steps and `depends_on`
4. Add tests for new functionality
5. Update documentation with examples
6. Maintain 100% backward compatibility

## Conclusion

Integrating Dagwood concepts would make SimpleFlow:
- **Smarter** - Automatic parallel detection
- **Cleaner** - Declarative dependencies vs manual parallel blocks
- **More Powerful** - Pipeline composition and merging
- **Easier to Debug** - Named steps instead of anonymous lambdas
- **More Testable** - Test individual steps by name

The most valuable improvement would be **automatic parallel detection** through dependency declaration, eliminating the need for manual `parallel` blocks while making dependencies explicit and clear.
