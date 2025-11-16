#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'
require 'timecop'
Timecop.travel(Time.local(2001, 9, 11, 7, 0, 0))

# Middleware examples showing logging, instrumentation, and custom middleware

puts "=" * 60
puts "Middleware Examples"
puts "=" * 60
puts

# Example 1: Logging middleware
puts "Example 1: Logging Middleware"
puts "-" * 60

pipeline_with_logging = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Logging

  step ->(result) {
    result.continue(result.value * 2)
  }

  step ->(result) {
    result.continue(result.value + 10)
  }
end

puts "Executing pipeline with logging middleware:"
result1 = pipeline_with_logging.call(SimpleFlow::Result.new(5))
puts "Final result: #{result1.value}"
puts

# Example 2: Instrumentation middleware
puts "\nExample 2: Instrumentation Middleware"
puts "-" * 60

pipeline_with_instrumentation = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'demo-key-123'

  step ->(result) {
    sleep 0.01  # Simulate work
    result.continue(result.value.upcase)
  }

  step ->(result) {
    sleep 0.02  # Simulate more work
    result.continue("Processed: #{result.value}")
  }
end

puts "Executing pipeline with instrumentation middleware:"
result2 = pipeline_with_instrumentation.call(SimpleFlow::Result.new("data"))
puts "Final result: #{result2.value}"
puts

# Example 3: Multiple middleware (stacked)
puts "\nExample 3: Stacked Middleware"
puts "-" * 60

pipeline_with_multiple = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'stacked-demo'
  use_middleware SimpleFlow::MiddleWare::Logging

  step ->(result) {
    result.continue(result.value + 5)
  }

  step ->(result) {
    result.continue(result.value * 3)
  }
end

puts "Executing pipeline with multiple middleware:"
result3 = pipeline_with_multiple.call(SimpleFlow::Result.new(10))
puts "Final result: #{result3.value}"
puts

# Example 4: Custom middleware - retry logic
puts "\nExample 4: Custom Retry Middleware"
puts "-" * 60

class RetryMiddleware
  def initialize(callable, max_retries: 3)
    @callable = callable
    @max_retries = max_retries
  end

  def call(result)
    attempts = 0
    begin
      attempts += 1
      puts "    Attempt #{attempts} of #{@max_retries}"
      @callable.call(result)
    rescue StandardError => e
      if attempts < @max_retries
        puts "    Failed (#{e.message}), retrying..."
        retry
      else
        puts "    Failed after #{@max_retries} attempts"
        result.halt.with_error(:retry, "Failed after #{@max_retries} attempts: #{e.message}")
      end
    end
  end
end

# Simulated flaky operation
attempt_count = 0
flaky_operation = ->(result) {
  attempt_count += 1
  if attempt_count < 2
    raise StandardError, "Temporary failure"
  end
  result.continue("Success on attempt #{attempt_count}")
}

retry_pipeline = SimpleFlow::Pipeline.new do
  use_middleware RetryMiddleware, max_retries: 3
  step flaky_operation
end

puts "Executing pipeline with retry middleware:"
result4 = retry_pipeline.call(SimpleFlow::Result.new(nil))
puts "Final result: #{result4.value}"
puts

# Example 5: Custom middleware - authentication
puts "\nExample 5: Custom Authentication Middleware"
puts "-" * 60

class AuthMiddleware
  def initialize(callable, required_role:)
    @callable = callable
    @required_role = required_role
  end

  def call(result)
    user_role = result.context[:user_role]

    unless user_role == @required_role
      puts "    Access denied: requires #{@required_role}, got #{user_role}"
      return result.halt.with_error(:auth, "Unauthorized: requires #{@required_role} role")
    end

    puts "    Access granted for #{@required_role}"
    @callable.call(result)
  end
end

auth_pipeline = SimpleFlow::Pipeline.new do
  # First step sets the user role in context
  step ->(result) {
    result.with_context(:user_role, result.value[:role]).continue(result.value)
  }

  # Protected step - requires admin role
  use_middleware AuthMiddleware, required_role: :admin

  step ->(result) {
    result.continue("Sensitive admin operation completed")
  }
end

# Test with admin role
puts "\nTest 1: Admin user"
admin_result = auth_pipeline.call(
  SimpleFlow::Result.new({ role: :admin })
)
puts "Continue? #{admin_result.continue?}"
puts "Result: #{admin_result.value}"
puts "Errors: #{admin_result.errors}"

# Test with regular user
puts "\nTest 2: Regular user"
user_result = auth_pipeline.call(
  SimpleFlow::Result.new({ role: :user })
)
puts "Continue? #{user_result.continue?}"
puts "Result: #{user_result.value}"
puts "Errors: #{user_result.errors}"

puts "\n" + "=" * 60
puts "Middleware examples completed!"
puts "=" * 60
