#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark/ips'
require_relative '../lib/simple_flow'

puts '=' * 80
puts 'SimpleFlow Performance Benchmarks: Parallel vs Sequential Execution'
puts '=' * 80
puts

# Simulate I/O operations with different delays
def io_operation(delay = 0.01)
  sleep delay
  :completed
end

# Define steps that perform I/O operations
step1 = ->(result) { io_operation(0.01); result.continue(result.value + 1) }
step2 = ->(result) { io_operation(0.01); result.continue(result.value + 1) }
step3 = ->(result) { io_operation(0.01); result.continue(result.value + 1) }
step4 = ->(result) { io_operation(0.01); result.continue(result.value + 1) }

# Sequential pipeline
sequential_pipeline = SimpleFlow::Pipeline.new do
  step step1
  step step2
  step step3
  step step4
end

# Parallel pipeline
parallel_pipeline = SimpleFlow::Pipeline.new do
  parallel do
    step step1
    step step2
    step step3
    step step4
  end
end

puts "Benchmark: 4 I/O operations (0.01s each)"
puts "Expected sequential time: ~0.04s"
puts "Expected parallel time: ~0.01s"
puts

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('sequential') do
    sequential_pipeline.call(SimpleFlow::Result.new(0))
  end

  x.report('parallel') do
    parallel_pipeline.call(SimpleFlow::Result.new(0))
  end

  x.compare!
end

puts "\n" + '=' * 80
puts

# Benchmark with varying number of parallel steps
puts 'Benchmark: Scaling with different numbers of parallel steps'
puts '=' * 80
puts

[2, 4, 8, 16].each do |count|
  steps = Array.new(count) { ->(r) { io_operation(0.005); r.continue(r.value) } }

  seq_pipeline = SimpleFlow::Pipeline.new
  steps.each { |s| seq_pipeline.step(s) }

  par_pipeline = SimpleFlow::Pipeline.new do
    parallel do
      steps.each { |s| step(s) }
    end
  end

  seq_time = Benchmark.realtime do
    seq_pipeline.call(SimpleFlow::Result.new(nil))
  end

  par_time = Benchmark.realtime do
    par_pipeline.call(SimpleFlow::Result.new(nil))
  end

  speedup = seq_time / par_time

  puts "\n#{count} steps (0.005s each):"
  puts "  Sequential: #{(seq_time * 1000).round(2)}ms"
  puts "  Parallel:   #{(par_time * 1000).round(2)}ms"
  puts "  Speedup:    #{speedup.round(2)}x"
end

puts "\n" + '=' * 80
