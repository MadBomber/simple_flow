#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Example: Error Handling and Recovery
# This example demonstrates various error handling patterns in SimpleFlow,
# including validation, error accumulation, and graceful degradation.

# Simulate API that may fail
class ExternalAPI
  def self.fetch_data(service_name, fail_rate: 0.0)
    sleep 0.02 # Simulate network delay

    if rand < fail_rate
      { success: false, error: "#{service_name} service unavailable" }
    else
      { success: true, data: "Data from #{service_name}" }
    end
  end
end

# Example 1: Validation with error accumulation
def validation_example
  puts "\n" + '=' * 70
  puts "Example 1: Validation with Error Accumulation"
  puts '=' * 70

  pipeline = SimpleFlow::Pipeline.new do
    parallel do
      # Email validation
      step ->(result) {
        email = result.value[:email]
        if email.nil? || !email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)+\z/i)
          result.with_error(:email, 'Invalid email format')
        else
          result
        end.continue(result.value)
      }

      # Age validation
      step ->(result) {
        age = result.value[:age]
        if age && (age < 0 || age > 150)
          result.with_error(:age, 'Age must be between 0 and 150')
        else
          result
        end.continue(result.value)
      }

      # Password validation
      step ->(result) {
        password = result.value[:password]
        errors = []
        errors << 'Password too short' if password && password.length < 8
        errors << 'Password must contain a number' if password && !password.match?(/\d/)

        errors.reduce(result) { |r, err| r.with_error(:password, err) }.continue(result.value)
      }
    end

    # Halt if any validation failed
    step ->(result) {
      result.errors.any? ? result.halt(result.value) : result.continue(result.value)
    }
  end

  test_data = { email: 'invalid@', age: 200, password: 'weak' }
  result = pipeline.call(SimpleFlow::Result.new(test_data))

  puts "\nInput: #{test_data.inspect}"
  if result.continue?
    puts "✓ Validation passed"
  else
    puts "✗ Validation failed with errors:"
    result.errors.each do |field, messages|
      messages.each { |msg| puts "  - #{field}: #{msg}" }
    end
  end
end

# Example 2: Graceful degradation with parallel services
def graceful_degradation_example
  puts "\n" + '=' * 70
  puts "Example 2: Graceful Degradation with Parallel Services"
  puts '=' * 70

  pipeline = SimpleFlow::Pipeline.new do
    step ->(result) {
      puts "\nFetching data from multiple services..."
      result.continue(result.value)
    }

    parallel do
      # Critical service (must succeed)
      step ->(result) {
        response = ExternalAPI.fetch_data('UserService', fail_rate: 0.0)
        if response[:success]
          result.with_context(:user_data, response[:data]).continue(result.value)
        else
          result.halt(result.value).with_error(:critical, response[:error])
        end
      }

      # Optional service (can fail gracefully)
      step ->(result) {
        response = ExternalAPI.fetch_data('RecommendationService', fail_rate: 0.5)
        if response[:success]
          result.with_context(:recommendations, response[:data])
        else
          result.with_context(:recommendations, 'default recommendations')
               .with_error(:warning, response[:error])
        end.continue(result.value)
      }

      # Optional service (can fail gracefully)
      step ->(result) {
        response = ExternalAPI.fetch_data('AnalyticsService', fail_rate: 0.5)
        if response[:success]
          result.with_context(:analytics, response[:data])
        else
          result.with_context(:analytics, nil)
               .with_error(:warning, response[:error])
        end.continue(result.value)
      }
    end

    step ->(result) {
      puts "\nServices completed:"
      puts "  User Data: #{result.context[:user_data]}"
      puts "  Recommendations: #{result.context[:recommendations]}"
      puts "  Analytics: #{result.context[:analytics] || 'Not available'}"

      if result.errors[:warning]
        puts "\nWarnings (non-critical):"
        result.errors[:warning].each { |w| puts "  - #{w}" }
      end

      result.continue(result.context)
    }
  end

  result = pipeline.call(SimpleFlow::Result.new(user_id: 123))

  if result.continue?
    puts "\n✓ Request completed successfully"
  else
    puts "\n✗ Request failed"
    puts "Errors: #{result.errors}"
  end
end

# Example 3: Retry logic
def retry_example
  puts "\n" + '=' * 70
  puts "Example 3: Retry Logic with Exponential Backoff"
  puts '=' * 70

  attempts = 0
  max_retries = 3

  pipeline = SimpleFlow::Pipeline.new do
    step ->(result) {
      success = false
      retries = 0

      while !success && retries <= max_retries
        puts "\n  Attempt #{retries + 1}/#{max_retries + 1}..."
        response = ExternalAPI.fetch_data('UnreliableService', fail_rate: 0.7)

        if response[:success]
          success = true
          puts "  ✓ Success!"
          result.with_context(:data, response[:data]).continue(result.value)
        else
          retries += 1
          if retries <= max_retries
            backoff = 0.1 * (2**retries) # Exponential backoff
            puts "  ✗ Failed: #{response[:error]}"
            puts "  Retrying in #{backoff}s..."
            sleep backoff
          else
            puts "  ✗ Max retries exceeded"
            result.halt(result.value).with_error(:service, "Failed after #{max_retries} retries")
          end
        end
      end

      result
    }
  end

  result = pipeline.call(SimpleFlow::Result.new(nil))

  if result.continue?
    puts "\n✓ Data retrieved: #{result.context[:data]}"
  else
    puts "\n✗ Failed to retrieve data"
    puts "Errors: #{result.errors}"
  end
end

# Run all examples
puts '=' * 70
puts 'SimpleFlow: Error Handling and Recovery Examples'
puts '=' * 70

validation_example
graceful_degradation_example
retry_example

puts "\n" + '=' * 70
puts "Examples completed"
puts '=' * 70
