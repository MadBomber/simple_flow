#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'
require 'timecop'
Timecop.travel(Time.local(2001, 9, 11, 7, 0, 0))

# Error handling and flow control examples

puts "=" * 60
puts "Error Handling and Flow Control"
puts "=" * 60
puts

# Example 1: Validation with halt
puts "Example 1: Input Validation with Halt"
puts "-" * 60

validation_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  Step 1: Validating age is numeric"
    unless result.value.is_a?(Integer)
      return result.halt.with_error(:validation, "Age must be a number")
    end
    result.continue(result.value)
  }

  step ->(result) {
    puts "  Step 2: Validating age is positive"
    if result.value < 0
      return result.halt.with_error(:validation, "Age cannot be negative")
    end
    result.continue(result.value)
  }

  step ->(result) {
    puts "  Step 3: Checking minimum age"
    if result.value < 18
      return result.halt.with_error(:validation, "Must be 18 or older")
    end
    result.continue(result.value)
  }

  step ->(result) {
    puts "  Step 4: Processing valid age"
    result.continue("Approved for age #{result.value}")
  }
end

# Test with valid age
puts "\nTest 1: Valid age (21)"
result1 = validation_pipeline.call(SimpleFlow::Result.new(21))
puts "Continue? #{result1.continue?}"
puts "Result: #{result1.value}"
puts "Errors: #{result1.errors}"

# Test with invalid age (under 18)
puts "\nTest 2: Invalid age (15)"
result2 = validation_pipeline.call(SimpleFlow::Result.new(15))
puts "Continue? #{result2.continue?}"
puts "Result: #{result2.value}"
puts "Errors: #{result2.errors}"

# Test with negative age
puts "\nTest 3: Negative age (-5)"
result3 = validation_pipeline.call(SimpleFlow::Result.new(-5))
puts "Continue? #{result3.continue?}"
puts "Result: #{result3.value}"
puts "Errors: #{result3.errors}"
puts

# Example 2: Error accumulation
puts "\nExample 2: Error Accumulation"
puts "-" * 60

error_accumulation_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  Step 1: Checking password length"
    if result.value[:password].length < 8
      result = result.with_error(:password, "Password must be at least 8 characters")
    end
    result.continue(result.value)
  }

  step ->(result) {
    puts "  Step 2: Checking for uppercase letters"
    unless result.value[:password] =~ /[A-Z]/
      result = result.with_error(:password, "Password must contain uppercase letters")
    end
    result.continue(result.value)
  }

  step ->(result) {
    puts "  Step 3: Checking for numbers"
    unless result.value[:password] =~ /[0-9]/
      result = result.with_error(:password, "Password must contain numbers")
    end
    result.continue(result.value)
  }

  step ->(result) {
    puts "  Step 4: Final validation"
    if result.errors.any?
      result.halt(result.value)
    else
      result.continue({ username: result.value[:username], status: "valid" })
    end
  }

  step ->(result) {
    puts "  Step 5: Creating account (only runs if valid)"
    result.continue("Account created for #{result.value[:username]}")
  }
end

# Test with weak password
puts "\nTest 1: Weak password"
weak_password_result = error_accumulation_pipeline.call(
  SimpleFlow::Result.new({ username: "john", password: "weak" })
)
puts "Continue? #{weak_password_result.continue?}"
puts "Result: #{weak_password_result.value}"
puts "Errors: #{weak_password_result.errors}"

# Test with strong password
puts "\nTest 2: Strong password"
strong_password_result = error_accumulation_pipeline.call(
  SimpleFlow::Result.new({ username: "jane", password: "SecurePass123" })
)
puts "Continue? #{strong_password_result.continue?}"
puts "Result: #{strong_password_result.value}"
puts "Errors: #{strong_password_result.errors}"
puts

# Example 3: Conditional branching
puts "\nExample 3: Conditional Processing"
puts "-" * 60

conditional_pipeline = SimpleFlow::Pipeline.new do
  step ->(result) {
    puts "  Step 1: Checking user role"
    result.with_context(:user_role, result.value[:role]).continue(result.value)
  }

  step ->(result) {
    puts "  Step 2: Role-based processing"
    case result.context[:user_role]
    when :admin
      result.with_context(:permissions, [:read, :write, :delete]).continue(result.value)
    when :editor
      result.with_context(:permissions, [:read, :write]).continue(result.value)
    when :viewer
      result.with_context(:permissions, [:read]).continue(result.value)
    else
      result.halt.with_error(:auth, "Unknown role: #{result.context[:user_role]}")
    end
  }

  step ->(result) {
    puts "  Step 3: Generating access token"
    permissions = result.context[:permissions]
    result.continue("Token granted with permissions: #{permissions.join(', ')}")
  }
end

# Test different roles
[:admin, :editor, :viewer, :unknown].each do |role|
  puts "\nTesting role: #{role}"
  result = conditional_pipeline.call(SimpleFlow::Result.new({ role: role }))
  puts "  Continue? #{result.continue?}"
  puts "  Result: #{result.value}"
  puts "  Errors: #{result.errors}" if result.errors.any?
  puts "  Permissions: #{result.context[:permissions]}" if result.context[:permissions]
end

puts "\n" + "=" * 60
puts "Error handling examples completed!"
puts "=" * 60
