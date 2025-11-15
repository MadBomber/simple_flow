# Best Practices for Concurrent Execution

This guide provides comprehensive best practices for designing, implementing, and debugging concurrent pipelines in SimpleFlow.

## Design Principles

### 1. Embrace Immutability

SimpleFlow's Result objects are immutable by design. Embrace this pattern throughout your pipeline:

```ruby
# GOOD: Creating new results
step :transform_data, ->(result) {
  transformed = result.value.map(&:upcase)
  result.continue(transformed)  # Returns new Result
}

# GOOD: Adding context
step :enrich_data, ->(result) {
  result
    .with_context(:timestamp, Time.now)
    .with_context(:source, "api")
    .continue(result.value)
}

# BAD: Mutating input
step :bad_transform, ->(result) {
  result.value.map!(&:upcase)  # Mutates shared data!
  result.continue(result.value)
}
```

### 2. Design Independent Steps

Parallel steps should be completely independent:

```ruby
# GOOD: Independent operations
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_weather, ->(result) {
    weather = WeatherAPI.fetch(result.value[:location])
    result.with_context(:weather, weather).continue(result.value)
  }, depends_on: []

  step :fetch_traffic, ->(result) {
    traffic = TrafficAPI.fetch(result.value[:location])
    result.with_context(:traffic, traffic).continue(result.value)
  }, depends_on: []
end

# BAD: Steps that depend on execution order
counter = 0
pipeline = SimpleFlow::Pipeline.new do
  step :increment, ->(result) {
    counter += 1  # Race condition!
    result.continue(result.value)
  }, depends_on: []

  step :read_counter, ->(result) {
    result.with_context(:count, counter).continue(result.value)
  }, depends_on: []
end
```

### 3. Use Context for Communication

Pass data between steps exclusively through the Result context:

```ruby
# GOOD: Context-based communication
pipeline = SimpleFlow::Pipeline.new do
  step :load_user, ->(result) {
    user = User.find(result.value)
    result.with_context(:user, user).continue(result.value)
  }, depends_on: []

  step :load_preferences, ->(result) {
    user_id = result.context[:user][:id]
    prefs = Preferences.find_by(user_id: user_id)
    result.with_context(:preferences, prefs).continue(result.value)
  }, depends_on: [:load_user]
end

# BAD: Instance variables
class PipelineRunner
  def initialize
    @shared_data = {}
  end

  def build_pipeline
    SimpleFlow::Pipeline.new do
      step :store_data, ->(result) {
        @shared_data[:key] = result.value  # Don't do this!
        result.continue(result.value)
      }, depends_on: []

      step :read_data, ->(result) {
        data = @shared_data[:key]  # Race condition!
        result.continue(data)
      }, depends_on: []
    end
  end
end
```

## Dependency Management

### 1. Declare All Dependencies Explicitly

Be exhaustive when declaring dependencies:

```ruby
# GOOD: All dependencies declared
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_data, ->(result) { ... }, depends_on: []
  step :validate_data, ->(result) { ... }, depends_on: [:fetch_data]
  step :transform_data, ->(result) { ... }, depends_on: [:validate_data]
  step :save_data, ->(result) { ... }, depends_on: [:transform_data]
end

# BAD: Missing dependencies
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_data, ->(result) { ... }, depends_on: []
  step :transform_data, ->(result) { ... }, depends_on: []  # Should depend on fetch_data!
  step :save_data, ->(result) { ... }, depends_on: [:transform_data]
end
```

### 2. Avoid Circular Dependencies

Circular dependencies will cause runtime errors:

```ruby
# BAD: Circular dependency
pipeline = SimpleFlow::Pipeline.new do
  step :step_a, ->(result) { ... }, depends_on: [:step_b]
  step :step_b, ->(result) { ... }, depends_on: [:step_a]
end
# Raises TSort::Cyclic error
```

### 3. Minimize Dependency Chains

Flatten dependency chains when possible to maximize parallelism:

```ruby
# GOOD: Maximum parallelism
pipeline = SimpleFlow::Pipeline.new do
  step :validate, ->(result) { ... }, depends_on: []

  # All depend only on validate - can run in parallel
  step :check_inventory, ->(result) { ... }, depends_on: [:validate]
  step :check_pricing, ->(result) { ... }, depends_on: [:validate]
  step :check_shipping, ->(result) { ... }, depends_on: [:validate]
  step :check_discounts, ->(result) { ... }, depends_on: [:validate]

  # Waits for all parallel steps
  step :finalize, ->(result) { ... }, depends_on: [
    :check_inventory,
    :check_pricing,
    :check_shipping,
    :check_discounts
  ]
end

# BAD: Sequential chain (slower)
pipeline = SimpleFlow::Pipeline.new do
  step :validate, ->(result) { ... }, depends_on: []
  step :check_inventory, ->(result) { ... }, depends_on: [:validate]
  step :check_pricing, ->(result) { ... }, depends_on: [:check_inventory]
  step :check_shipping, ->(result) { ... }, depends_on: [:check_pricing]
  step :finalize, ->(result) { ... }, depends_on: [:check_shipping]
end
# All steps run sequentially!
```

## Error Handling

### 1. Validate Early

Place validation steps before expensive parallel operations:

```ruby
# GOOD: Validate before parallel execution
pipeline = SimpleFlow::Pipeline.new do
  step :validate_input, ->(result) {
    if result.value[:email].nil?
      return result.halt.with_error(:validation, "Email required")
    end
    result.continue(result.value)
  }, depends_on: []

  # Only execute if validation passes
  step :fetch_user, ->(result) { ... }, depends_on: [:validate_input]
  step :fetch_orders, ->(result) { ... }, depends_on: [:validate_input]
  step :fetch_preferences, ->(result) { ... }, depends_on: [:validate_input]
end

# BAD: Validate after expensive operations
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, ->(result) { ... }, depends_on: []
  step :fetch_orders, ->(result) { ... }, depends_on: []
  step :fetch_preferences, ->(result) { ... }, depends_on: []

  step :validate_results, ->(result) {
    # Too late - already did expensive work!
    if result.errors.any?
      result.halt(result.value)
    end
  }, depends_on: [:fetch_user, :fetch_orders, :fetch_preferences]
end
```

### 2. Accumulate Errors, Then Halt

For validation pipelines, accumulate all errors before halting:

```ruby
# GOOD: Collect all validation errors
pipeline = SimpleFlow::Pipeline.new do
  step :validate_email, ->(result) {
    if invalid_email?(result.value[:email])
      result.with_error(:email, "Invalid email format")
    else
      result.continue(result.value)
    end
  }, depends_on: []

  step :validate_phone, ->(result) {
    if invalid_phone?(result.value[:phone])
      result.with_error(:phone, "Invalid phone format")
    else
      result.continue(result.value)
    end
  }, depends_on: []

  step :validate_age, ->(result) {
    if result.value[:age] < 18
      result.with_error(:age, "Must be 18 or older")
    else
      result.continue(result.value)
    end
  }, depends_on: []

  # Check all errors at once
  step :check_validations, ->(result) {
    if result.errors.any?
      result.halt(result.value)
    else
      result.continue(result.value)
    end
  }, depends_on: [:validate_email, :validate_phone, :validate_age]
end

# User gets all validation errors at once, not just the first one
```

### 3. Add Context to Errors

Include helpful debugging information:

```ruby
step :process_file, ->(result) {
  begin
    data = File.read(result.value[:path])
    parsed = JSON.parse(data)
    result.with_context(:file_size, data.size).continue(parsed)
  rescue Errno::ENOENT => e
    result.halt.with_error(
      :file_error,
      "File not found: #{result.value[:path]}"
    )
  rescue JSON::ParserError => e
    result.halt.with_error(
      :parse_error,
      "Invalid JSON in #{result.value[:path]}: #{e.message}"
    )
  end
}
```

## Performance Optimization

### 1. Use Parallelism for I/O Operations

Prioritize parallelizing I/O-bound operations:

```ruby
# GOOD: Parallel I/O operations
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_api_a, ->(result) {
    # Network I/O - benefits from parallelism
    response = HTTP.get("https://api-a.example.com")
    result.with_context(:api_a, response).continue(result.value)
  }, depends_on: []

  step :fetch_api_b, ->(result) {
    # Network I/O - benefits from parallelism
    response = HTTP.get("https://api-b.example.com")
    result.with_context(:api_b, response).continue(result.value)
  }, depends_on: []
end

# Sequential: ~200ms (100ms per API call)
# Parallel: ~100ms
# Speedup: 2x
```

### 2. Keep CPU-Bound Operations Sequential

Don't parallelize CPU-intensive calculations (due to GIL):

```ruby
# Keep CPU-bound operations sequential
pipeline = SimpleFlow::Pipeline.new do
  step :calculate_fibonacci, ->(result) {
    # CPU-bound - no benefit from parallelism
    fib = calculate_fib(result.value)
    result.continue(fib)
  }, depends_on: []

  step :process_result, ->(result) {
    result.continue(result.value * 2)
  }, depends_on: [:calculate_fibonacci]
end
```

### 3. Minimize Context Payload

Keep context lean to reduce merging overhead:

```ruby
# GOOD: Minimal context
step :fetch_users, ->(result) {
  users = UserService.all
  user_count = users.size
  result.with_context(:user_count, user_count).continue(result.value)
}

# BAD: Large context
step :fetch_users, ->(result) {
  users = UserService.all  # Could be thousands of records
  result.with_context(:all_users, users).continue(result.value)
}
```

## Testing Strategies

### 1. Test Steps in Isolation

Design steps to be testable independently:

```ruby
# GOOD: Testable step
class FetchUserStep
  def call(result)
    user = UserService.find(result.value)
    result.with_context(:user, user).continue(result.value)
  end
end

# Easy to test
describe FetchUserStep do
  it "fetches user and adds to context" do
    step = FetchUserStep.new
    result = SimpleFlow::Result.new(123)

    output = step.call(result)

    expect(output.context[:user]).to be_present
    expect(output.continue?).to be true
  end
end

# Use in pipeline
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_user, FetchUserStep.new, depends_on: []
end
```

### 2. Test Dependency Graphs

Verify your dependency structure:

```ruby
describe "OrderPipeline" do
  let(:pipeline) { OrderPipeline.build }

  it "has correct dependency structure" do
    graph = pipeline.dependency_graph

    expect(graph.dependencies[:validate_order]).to eq([])
    expect(graph.dependencies[:check_inventory]).to eq([:validate_order])
    expect(graph.dependencies[:calculate_total]).to eq([
      :check_inventory,
      :check_pricing
    ])
  end

  it "groups parallel steps correctly" do
    graph = pipeline.dependency_graph
    groups = graph.parallel_order

    # Check inventory and pricing run in parallel
    expect(groups[1]).to include(:check_inventory, :check_pricing)
  end
end
```

### 3. Test Both Sequential and Parallel Execution

Ensure your pipeline works in both modes:

```ruby
describe "DataPipeline" do
  let(:pipeline) { DataPipeline.build }
  let(:input) { SimpleFlow::Result.new(data) }

  it "produces same result sequentially" do
    result = pipeline.call(input)
    expect(result.value).to eq(expected_output)
  end

  it "produces same result in parallel" do
    result = pipeline.call_parallel(input)
    expect(result.value).to eq(expected_output)
  end

  it "merges context from parallel steps" do
    result = pipeline.call_parallel(input)
    expect(result.context).to include(:data_a, :data_b, :data_c)
  end
end
```

## Debugging Techniques

### 1. Use Visualization Tools

Visualize your pipeline to understand execution flow:

```ruby
pipeline = OrderPipeline.build

# ASCII visualization for quick debugging
puts pipeline.visualize_ascii

# Detailed execution plan
puts pipeline.execution_plan

# Generate diagram for documentation
File.write('pipeline.dot', pipeline.visualize_dot)
system('dot -Tpng pipeline.dot -o pipeline.png')
```

### 2. Add Logging Middleware

Use middleware to trace execution:

```ruby
class DetailedLogging
  def initialize(callable, step_name: nil)
    @callable = callable
    @step_name = step_name
  end

  def call(result)
    puts "[#{Time.now}] Starting #{@step_name}"
    puts "  Input value: #{result.value.inspect}"

    output = @callable.call(result)

    puts "[#{Time.now}] Completed #{@step_name}"
    puts "  Output value: #{output.value.inspect}"
    puts "  Continue? #{output.continue?}"
    puts "  Errors: #{output.errors}" if output.errors.any?
    puts

    output
  end
end

pipeline = SimpleFlow::Pipeline.new do
  use_middleware DetailedLogging, step_name: "pipeline step"

  step :fetch_data, ->(result) { ... }, depends_on: []
  step :process_data, ->(result) { ... }, depends_on: [:fetch_data]
end
```

### 3. Track Step Execution Time

Measure performance of individual steps:

```ruby
class TimingMiddleware
  def initialize(callable, step_name:)
    @callable = callable
    @step_name = step_name
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

pipeline = SimpleFlow::Pipeline.new do
  use_middleware TimingMiddleware, step_name: "my_step"

  step :slow_operation, ->(result) { ... }, depends_on: []
end

result = pipeline.call(initial_data)
puts "Execution time: #{result.context[:slow_operation_duration]}s"
```

## Code Organization

### 1. Extract Steps to Classes

For complex steps, use dedicated classes:

```ruby
# GOOD: Dedicated step classes
module OrderPipeline
  class ValidateOrder
    def call(result)
      order = result.value
      errors = []

      errors << "Missing email" unless order[:email]
      errors << "No items" if order[:items].empty?

      if errors.any?
        result.halt.with_error(:validation, errors.join(", "))
      else
        result.continue(order)
      end
    end
  end

  class CalculateTotal
    def call(result)
      items = result.context[:items]
      shipping = result.context[:shipping]

      subtotal = items.sum { |i| i[:price] * i[:quantity] }
      total = subtotal + shipping

      result.with_context(:total, total).continue(result.value)
    end
  end

  def self.build
    SimpleFlow::Pipeline.new do
      step :validate, ValidateOrder.new, depends_on: []
      step :calculate_total, CalculateTotal.new, depends_on: [:validate]
    end
  end
end
```

### 2. Use Builder Pattern

Create pipeline builders for complex workflows:

```ruby
class EcommercePipelineBuilder
  def self.build(options = {})
    SimpleFlow::Pipeline.new do
      if options[:enable_logging]
        use_middleware SimpleFlow::MiddleWare::Logging
      end

      # Validation phase
      step :validate_order, ValidateOrder.new, depends_on: []

      # Parallel checks
      step :check_inventory, CheckInventory.new, depends_on: [:validate_order]
      step :check_pricing, CheckPricing.new, depends_on: [:validate_order]
      step :check_shipping, CheckShipping.new, depends_on: [:validate_order]

      # Process payment
      step :calculate_total, CalculateTotal.new,
        depends_on: [:check_inventory, :check_pricing, :check_shipping]

      step :process_payment, ProcessPayment.new,
        depends_on: [:calculate_total]
    end
  end
end

# Use in application
pipeline = EcommercePipelineBuilder.build(enable_logging: true)
result = pipeline.call_parallel(order_data)
```

### 3. Document Dependencies

Add comments explaining why dependencies exist:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Must validate before any processing
  step :validate_input, ->(result) { ... }, depends_on: []

  # These checks are independent and can run in parallel
  step :check_inventory, ->(result) { ... }, depends_on: [:validate_input]
  step :check_pricing, ->(result) { ... }, depends_on: [:validate_input]

  # Discount requires both inventory (stock levels) and pricing
  step :calculate_discount, ->(result) { ... },
    depends_on: [:check_inventory, :check_pricing]
end
```

## Common Pitfalls

### 1. Avoid Premature Parallelization

Don't parallelize until you have measured performance:

```ruby
# Start simple
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { fetch_data(result.value) }
  step ->(result) { transform_data(result.value) }
  step ->(result) { save_data(result.value) }
end

# Measure
time = Benchmark.realtime { pipeline.call(data) }

# Only add parallelism if it helps
if time > 1.0  # If pipeline takes > 1 second
  # Refactor to use named steps with parallelism
end
```

### 2. Don't Parallelize Everything

Not all steps benefit from parallelism:

```ruby
# BAD: Unnecessary parallelism
pipeline = SimpleFlow::Pipeline.new do
  step :upcase, ->(result) {
    result.continue(result.value.upcase)  # Fast operation
  }, depends_on: []

  step :reverse, ->(result) {
    result.continue(result.value.reverse)  # Fast operation
  }, depends_on: []
end

# Parallel overhead > benefit for fast operations
```

### 3. Watch for Deadlocks

Ensure database connections and resources are properly managed:

```ruby
# GOOD: Connection pooling
DB = Sequel.connect(
  'postgres://localhost/db',
  max_connections: 10  # Allow 10 concurrent connections
)

# BAD: Single connection
DB = Sequel.connect('postgres://localhost/db')
# Parallel steps will deadlock waiting for the connection!
```

## Related Documentation

- [Parallel Steps Guide](parallel-steps.md) - How to use named steps with dependencies
- [Performance Guide](performance.md) - Understanding parallel execution performance
- [Testing Guide](../development/testing.md) - Testing strategies for pipelines
- [Pipeline API](../api/pipeline.md) - Complete Pipeline API reference
