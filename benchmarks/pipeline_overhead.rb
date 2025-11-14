#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark/ips'
require_relative '../lib/simple_flow'

puts '=' * 80
puts 'SimpleFlow Performance Benchmarks: Pipeline Overhead'
puts '=' * 80
puts

# Simple operation for measuring overhead
simple_op = ->(x) { x + 1 }

# Baseline: raw operations
def raw_operations(value)
  value += 1
  value += 1
  value += 1
  value += 1
  value
end

# Pipeline operations
pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
end

puts "Comparing raw operations vs Pipeline"
puts

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('raw operations') do
    raw_operations(0)
  end

  x.report('pipeline') do
    pipeline.call(SimpleFlow::Result.new(0))
  end

  x.compare!
end

puts "\n" + '=' * 80
puts

# Middleware overhead
puts 'Benchmark: Middleware Overhead'
puts '=' * 80
puts

no_middleware = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
end

with_middleware = SimpleFlow::Pipeline.new do
  use_middleware SimpleFlow::MiddleWare::Instrumentation, api_key: 'test'

  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
  step ->(result) { result.continue(result.value + 1) }
end

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('no middleware') do
    no_middleware.call(SimpleFlow::Result.new(0))
  end

  x.report('with instrumentation') do |times|
    # Suppress output
    original_stdout = $stdout
    $stdout = File.open(File::NULL, 'w')
    times.times do
      with_middleware.call(SimpleFlow::Result.new(0))
    end
    $stdout = original_stdout
  end

  x.compare!
end

puts "\n" + '=' * 80
puts

# Result creation overhead
puts 'Benchmark: Result Creation and Immutability'
puts '=' * 80
puts

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('new result') do
    SimpleFlow::Result.new(42)
  end

  x.report('with_context') do
    result = SimpleFlow::Result.new(42)
    result.with_context(:key, 'value')
  end

  x.report('with_error') do
    result = SimpleFlow::Result.new(42)
    result.with_error(:error, 'message')
  end

  x.report('continue') do
    result = SimpleFlow::Result.new(42)
    result.continue(43)
  end

  x.report('halt') do
    result = SimpleFlow::Result.new(42)
    result.halt
  end

  x.compare!
end

puts "\n" + '=' * 80
