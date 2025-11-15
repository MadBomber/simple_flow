# Testing Guide

This guide covers testing strategies, patterns, and best practices for SimpleFlow.

## Test Suite Overview

SimpleFlow uses Minitest for its test suite.

**Current Coverage:**
- **121 tests**
- **296 assertions**
- **96.61% code coverage**
- **All tests passing**

## Running Tests

### Run All Tests

```bash
bundle exec rake test
```

Expected output:
```
Run options: --seed 12345

# Running:

.............................................................................

Finished in 0.123456s, 987.65 runs/s, 2345.67 assertions/s.

121 tests, 296 assertions, 0 failures, 0 errors, 0 skips
```

### Run Specific Test File

```bash
ruby -Ilib:test test/pipeline_test.rb
```

### Run Specific Test

```bash
ruby -Ilib:test test/pipeline_test.rb -n test_basic_pipeline
```

### Run Tests with Verbose Output

```bash
ruby -Ilib:test test/pipeline_test.rb --verbose
```

## Test Organization

Tests are organized by component:

```
test/
├── test_helper.rb                   # Test configuration and helpers
├── result_test.rb                   # Result class tests
├── pipeline_test.rb                 # Pipeline class tests
├── middleware_test.rb               # Middleware tests
├── parallel_execution_test.rb       # Parallel execution tests
├── dependency_graph_test.rb         # Dependency graph tests
├── dependency_graph_visualizer_test.rb  # Visualization tests
├── pipeline_visualization_test.rb   # Pipeline visualization tests
└── step_tracker_test.rb             # StepTracker tests
```

## Writing Tests

### Basic Test Structure

```ruby
require 'test_helper'

class MyFeatureTest < Minitest::Test
  def setup
    # Runs before each test
    @pipeline = SimpleFlow::Pipeline.new
  end

  def test_feature_description
    # Arrange
    initial = SimpleFlow::Result.new(42)

    # Act
    result = @pipeline.call(initial)

    # Assert
    assert result.continue?
    assert_equal 42, result.value
  end

  def teardown
    # Runs after each test (if needed)
  end
end
```

### Testing Result Objects

```ruby
class ResultTest < Minitest::Test
  def test_new_result_has_default_values
    result = SimpleFlow::Result.new(42)

    assert_equal 42, result.value
    assert_equal({}, result.context)
    assert_equal({}, result.errors)
    assert result.continue?
  end

  def test_with_context_adds_context
    result = SimpleFlow::Result.new(42)
      .with_context(:user_id, 123)
      .with_context(:timestamp, Time.now)

    assert_equal 123, result.context[:user_id]
    assert result.context[:timestamp]
  end

  def test_with_error_accumulates_errors
    result = SimpleFlow::Result.new(nil)
      .with_error(:validation, "Error 1")
      .with_error(:validation, "Error 2")

    assert_equal 2, result.errors[:validation].size
    assert_includes result.errors[:validation], "Error 1"
    assert_includes result.errors[:validation], "Error 2"
  end

  def test_halt_stops_continuation
    result = SimpleFlow::Result.new(42).halt

    refute result.continue?
  end

  def test_immutability
    original = SimpleFlow::Result.new(42)
    modified = original.with_context(:key, "value")

    assert_equal({}, original.context)
    assert_equal({ key: "value" }, modified.context)
    refute_equal original.object_id, modified.object_id
  end
end
```

### Testing Pipelines

```ruby
class PipelineTest < Minitest::Test
  def test_basic_sequential_execution
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(result.value + 1) }
      step ->(result) { result.continue(result.value * 2) }
    end

    result = pipeline.call(SimpleFlow::Result.new(5))

    assert_equal 12, result.value  # (5 + 1) * 2
    assert result.continue?
  end

  def test_pipeline_halts_on_error
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(result.value + 1) }
      step ->(result) { result.halt.with_error(:error, "Failed") }
      step ->(result) { result.continue(result.value * 2) }  # Should not execute
    end

    result = pipeline.call(SimpleFlow::Result.new(5))

    assert_equal 6, result.value  # Only first step executed
    refute result.continue?
    assert_includes result.errors[:error], "Failed"
  end

  def test_pipeline_with_middleware
    executed = []

    logging_middleware = ->(callable) {
      ->(result) {
        executed << :before
        output = callable.call(result)
        executed << :after
        output
      }
    }

    pipeline = SimpleFlow::Pipeline.new do
      use_middleware logging_middleware

      step ->(result) {
        executed << :step
        result.continue(result.value)
      }
    end

    pipeline.call(SimpleFlow::Result.new(nil))

    assert_equal [:before, :step, :after], executed
  end
end
```

### Testing Parallel Execution

```ruby
class ParallelExecutionTest < Minitest::Test
  def test_parallel_steps_execute_concurrently
    skip unless SimpleFlow::Pipeline.new.async_available?

    execution_order = []
    mutex = Mutex.new

    pipeline = SimpleFlow::Pipeline.new do
      step :step_a, ->(result) {
        mutex.synchronize { execution_order << :a_start }
        sleep 0.1
        mutex.synchronize { execution_order << :a_end }
        result.with_context(:a, true).continue(result.value)
      }, depends_on: []

      step :step_b, ->(result) {
        mutex.synchronize { execution_order << :b_start }
        sleep 0.1
        mutex.synchronize { execution_order << :b_end }
        result.with_context(:b, true).continue(result.value)
      }, depends_on: []
    end

    result = pipeline.call_parallel(SimpleFlow::Result.new(nil))

    assert result.context[:a]
    assert result.context[:b]

    # Both steps started before either finished
    a_start_index = execution_order.index(:a_start)
    b_start_index = execution_order.index(:b_start)
    a_end_index = execution_order.index(:a_end)
    b_end_index = execution_order.index(:b_end)

    assert a_start_index < a_end_index
    assert b_start_index < b_end_index
  end

  def test_parallel_execution_merges_contexts
    pipeline = SimpleFlow::Pipeline.new do
      step :step_a, ->(result) {
        result.with_context(:data_a, "from A").continue(result.value)
      }, depends_on: []

      step :step_b, ->(result) {
        result.with_context(:data_b, "from B").continue(result.value)
      }, depends_on: []

      step :combine, ->(result) {
        assert_equal "from A", result.context[:data_a]
        assert_equal "from B", result.context[:data_b]
        result.continue(result.value)
      }, depends_on: [:step_a, :step_b]
    end

    result = pipeline.call_parallel(SimpleFlow::Result.new(nil))
    assert result.continue?
  end
end
```

### Testing Middleware

```ruby
class MiddlewareTest < Minitest::Test
  def test_logging_middleware_logs_execution
    output = StringIO.new
    logger = Logger.new(output)

    pipeline = SimpleFlow::Pipeline.new do
      use_middleware SimpleFlow::MiddleWare::Logging, logger: logger

      step ->(result) { result.continue(result.value) }
    end

    pipeline.call(SimpleFlow::Result.new(42))

    log_output = output.string
    assert_match(/Before call/, log_output)
    assert_match(/After call/, log_output)
  end

  def test_instrumentation_middleware_measures_time
    output = StringIO.new
    $stdout = output

    pipeline = SimpleFlow::Pipeline.new do
      use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'test'

      step ->(result) {
        sleep 0.01
        result.continue(result.value)
      }
    end

    pipeline.call(SimpleFlow::Result.new(nil))

    $stdout = STDOUT
    assert_match(/Instrumentation: test took/, output.string)
  end
end
```

## Testing Patterns

### Testing Step Classes

```ruby
class FetchUserStep
  def call(result)
    user = User.find(result.value)
    result.with_context(:user, user).continue(result.value)
  end
end

class FetchUserStepTest < Minitest::Test
  def test_fetches_user_and_adds_to_context
    # Mock User.find
    user = { id: 123, name: "John" }
    User.stub :find, user do
      step = FetchUserStep.new
      result = step.call(SimpleFlow::Result.new(123))

      assert_equal user, result.context[:user]
      assert result.continue?
    end
  end

  def test_handles_user_not_found
    User.stub :find, nil do
      step = FetchUserStep.new
      result = step.call(SimpleFlow::Result.new(999))

      assert_nil result.context[:user]
    end
  end
end
```

### Testing Error Handling

```ruby
def test_validation_errors
  pipeline = SimpleFlow::Pipeline.new do
    step ->(result) {
      if result.value[:email].nil?
        result.with_error(:validation, "Email required")
      end

      if result.value[:password].nil?
        result.with_error(:validation, "Password required")
      end

      if result.errors.any?
        result.halt(result.value)
      else
        result.continue(result.value)
      end
    }
  end

  result = pipeline.call(SimpleFlow::Result.new({ email: nil, password: nil }))

  refute result.continue?
  assert_equal 2, result.errors[:validation].size
  assert_includes result.errors[:validation], "Email required"
  assert_includes result.errors[:validation], "Password required"
end
```

### Testing with Mocks and Stubs

```ruby
def test_external_api_call
  # Stub HTTP client
  mock_response = { status: "ok", data: [1, 2, 3] }

  HTTP.stub :get, mock_response do
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) {
        response = HTTP.get("https://api.example.com")
        result.continue(response[:data])
      }
    end

    result = pipeline.call(SimpleFlow::Result.new(nil))

    assert_equal [1, 2, 3], result.value
  end
end
```

## Best Practices

### 1. Test Public Interfaces

Focus on testing public methods and behaviors:

```ruby
# GOOD: Tests public interface
def test_pipeline_processes_data
  result = pipeline.call(initial_data)
  assert_equal expected_output, result.value
end

# AVOID: Testing internal implementation
def test_internal_step_processing
  # Don't test private methods directly
end
```

### 2. Use Descriptive Test Names

```ruby
# GOOD: Clear what is being tested
def test_pipeline_halts_when_validation_fails
def test_parallel_steps_merge_contexts
def test_middleware_wraps_steps_in_correct_order

# BAD: Vague test names
def test_pipeline
def test_it_works
```

### 3. Test Edge Cases

```ruby
def test_handles_nil_value
def test_handles_empty_array
def test_handles_large_dataset
def test_handles_unicode_characters
```

### 4. Keep Tests Focused

```ruby
# GOOD: Tests one thing
def test_with_context_adds_context
  result = SimpleFlow::Result.new(42).with_context(:key, "value")
  assert_equal "value", result.context[:key]
end

# BAD: Tests multiple things
def test_result_functionality
  # Tests context, errors, halt, continue all in one test
end
```

### 5. Use Setup and Teardown

```ruby
class PipelineTest < Minitest::Test
  def setup
    @pipeline = create_test_pipeline
    @initial_data = SimpleFlow::Result.new(test_data)
  end

  def teardown
    cleanup_test_data if needed
  end

  def test_something
    result = @pipeline.call(@initial_data)
    # Test assertions
  end
end
```

## Running Tests in CI

SimpleFlow uses GitHub Actions for continuous integration. Tests run automatically on:

- Every push to any branch
- Every pull request
- Multiple Ruby versions (2.7, 3.0, 3.1, 3.2, 3.3)

## Coverage Reports

To generate coverage reports locally:

```ruby
# Add to test_helper.rb
require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end
```

Run tests:
```bash
bundle exec rake test
```

View coverage:
```bash
open coverage/index.html
```

## Related Documentation

- [Contributing Guide](contributing.md) - How to contribute
- [Benchmarking Guide](benchmarking.md) - Performance testing
- [Examples](/Users/dewayne/sandbox/git_repos/madbomber/simple_flow/examples/) - Working examples to test against
