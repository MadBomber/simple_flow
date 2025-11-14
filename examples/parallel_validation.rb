#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Example: Parallel Validation
# This example demonstrates how to run multiple validation checks in parallel
# to quickly identify all validation errors.

# Build a pipeline for validating user registration data
validation_pipeline = SimpleFlow::Pipeline.new do
  # Run all validations in parallel
  parallel do
    # Email validation
    step ->(result) {
      data = result.value
      email = data[:email]

      if email.nil? || email.empty?
        result.with_error(:email, "Email is required")
      elsif !email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
        result.with_error(:email, "Email format is invalid")
      else
        result
      end.continue(data)
    }

    # Password validation
    step ->(result) {
      data = result.value
      password = data[:password]

      errors = []
      errors << "Password is required" if password.nil? || password.empty?
      errors << "Password must be at least 8 characters" if password && password.length < 8
      errors << "Password must contain a number" if password && !password.match?(/\d/)
      errors << "Password must contain an uppercase letter" if password && !password.match?(/[A-Z]/)

      result_with_errors = errors.reduce(result) do |r, error|
        r.with_error(:password, error)
      end

      result_with_errors.continue(data)
    }

    # Username validation
    step ->(result) {
      data = result.value
      username = data[:username]

      if username.nil? || username.empty?
        result.with_error(:username, "Username is required")
      elsif username.length < 3
        result.with_error(:username, "Username must be at least 3 characters")
      elsif !username.match?(/\A[a-z0-9_]+\z/i)
        result.with_error(:username, "Username can only contain letters, numbers, and underscores")
      else
        result
      end.continue(data)
    }

    # Age validation
    step ->(result) {
      data = result.value
      age = data[:age]

      if age.nil?
        result.with_error(:age, "Age is required")
      elsif age < 13
        result.with_error(:age, "Must be at least 13 years old")
      elsif age > 120
        result.with_error(:age, "Age must be realistic")
      else
        result
      end.continue(data)
    }
  end

  # Check if any validations failed
  step ->(result) {
    if result.errors.any?
      result.halt(result.value)
    else
      result.continue(result.value)
    end
  }
end

# Test cases
test_cases = [
  {
    name: "Valid user",
    data: {
      email: "john@example.com",
      password: "SecurePass123",
      username: "john_doe",
      age: 25
    }
  },
  {
    name: "Invalid email and weak password",
    data: {
      email: "invalid-email",
      password: "weak",
      username: "john_doe",
      age: 25
    }
  },
  {
    name: "Multiple validation errors",
    data: {
      email: "bad@email",
      password: "short",
      username: "ab",
      age: 10
    }
  },
  {
    name: "Missing required fields",
    data: {
      email: nil,
      password: nil,
      username: nil,
      age: nil
    }
  }
]

# Run validations
test_cases.each do |test_case|
  puts "\n" + "=" * 60
  puts "Testing: #{test_case[:name]}"
  puts "=" * 60

  start_time = Time.now
  result = validation_pipeline.call(SimpleFlow::Result.new(test_case[:data]))
  elapsed = Time.now - start_time

  if result.continue?
    puts "✓ Validation PASSED (#{(elapsed * 1000).round(2)}ms)"
    puts "  User data is valid and ready for registration"
  else
    puts "✗ Validation FAILED (#{(elapsed * 1000).round(2)}ms)"
    puts "\n  Errors found:"
    result.errors.each do |field, messages|
      messages.each do |message|
        puts "    • #{field}: #{message}"
      end
    end
  end
end

puts "\n" + "=" * 60
puts "Note: All validations run in parallel for faster feedback"
puts "=" * 60
