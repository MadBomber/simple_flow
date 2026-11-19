# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  # call_parallel raises on a depends_on cycle instead of silently skipping
  # the steps in it (issue #31)
  class DependencyCycleTest < Minitest::Test
    MARK = ->(r) { r.continue(r.value) }

    def test_call_parallel_raises_on_a_two_step_cycle
      pipeline = Pipeline.new do
        step :a, MARK, depends_on: [:b]
        step :b, MARK, depends_on: [:a]
        step :c, MARK, depends_on: :none
      end

      error = assert_raises(ArgumentError) { pipeline.call_parallel(Result.new(1)) }

      assert_includes error.message, 'Circular depends_on'
      assert_includes error.message, ':a'
      assert_includes error.message, ':b'
      refute_includes error.message, ':c'
    end

    def test_call_parallel_raises_on_a_self_dependency
      pipeline = Pipeline.new do
        step :a, MARK, depends_on: [:a]
        step :b, MARK, depends_on: :none
      end

      error = assert_raises(ArgumentError) { pipeline.call_parallel(Result.new(1)) }

      assert_equal 'Circular depends_on among steps: :a', error.message
    end

    def test_find_dependency_cycle_returns_the_steps_in_the_cycle
      cycle = Pipeline.new.send(:find_dependency_cycle, { a: [:c], b: [:a], c: [:b], d: [] })

      assert_equal %i[a b c], cycle.sort
    end

    def test_find_dependency_cycle_returns_nil_without_a_cycle
      assert_nil Pipeline.new.send(:find_dependency_cycle, { a: [], b: [:a], c: %i[a b] })
    end

    def test_acyclic_pipeline_still_runs
      pipeline = Pipeline.new do
        step :a, ->(r) { r.with_context(:a, 1).continue(r.value) }, depends_on: :none
        step :b, ->(r) { r.with_context(:b, 1).continue(r.value) }, depends_on: [:a]
      end

      assert_equal({ a: 1, b: 1 }, pipeline.call_parallel(Result.new(1)).context)
    end
  end
end
