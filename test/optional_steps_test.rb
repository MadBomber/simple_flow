# frozen_string_literal: true

require_relative 'test_helper'

module SimpleFlow
  class OptionalStepsTest < Minitest::Test
    # ===========================================
    # Result#activate tests
    # ===========================================

    def test_activate_returns_new_result_with_step_added
      result = Result.new('value')
      activated = result.activate(:step_a)

      refute_equal result.object_id, activated.object_id
      assert_equal [:step_a], activated.activated_steps
      assert_empty result.activated_steps
    end

    def test_activate_multiple_steps_at_once
      result = Result.new('value')
      activated = result.activate(:step_a, :step_b, :step_c)

      assert_equal [:step_a, :step_b, :step_c], activated.activated_steps
    end

    def test_activate_accumulates_steps
      result = Result.new('value')
        .activate(:step_a)
        .activate(:step_b)
        .activate(:step_c)

      assert_equal [:step_a, :step_b, :step_c], result.activated_steps
    end

    def test_activate_preserves_continue_state
      halted = Result.new('value').halt
      activated = halted.activate(:step_a)

      refute activated.continue?
      assert_equal [:step_a], activated.activated_steps
    end

    def test_activate_preserves_context
      result = Result.new('value').with_context(:user, 123)
      activated = result.activate(:step_a)

      assert_equal({ user: 123 }, activated.context)
    end

    def test_activate_preserves_errors
      result = Result.new('value').with_error(:validation, 'Invalid')
      activated = result.activate(:step_a)

      assert_equal({ validation: ['Invalid'] }, activated.errors)
    end

    def test_activate_preserves_value
      result = Result.new('original')
      activated = result.activate(:step_a)

      assert_equal 'original', activated.value
    end

    def test_activated_steps_preserved_through_continue
      result = Result.new('start')
        .activate(:step_a)
        .continue('new_value')

      assert_equal 'new_value', result.value
      assert_equal [:step_a], result.activated_steps
    end

    def test_activated_steps_preserved_through_with_context
      result = Result.new('value')
        .activate(:step_a)
        .with_context(:key, 'val')

      assert_equal [:step_a], result.activated_steps
    end

    def test_activated_steps_preserved_through_with_error
      result = Result.new('value')
        .activate(:step_a)
        .with_error(:key, 'error')

      assert_equal [:step_a], result.activated_steps
    end

    def test_activated_steps_preserved_through_halt
      result = Result.new('value')
        .activate(:step_a)
        .halt

      assert_equal [:step_a], result.activated_steps
    end

    # ===========================================
    # Optional step declaration tests
    # ===========================================

    def test_depends_on_optional_adds_to_optional_steps
      pipeline = Pipeline.new do
        step :regular, ->(r) { r }, depends_on: :none
        step :optional_step, ->(r) { r }, depends_on: :optional
      end

      assert pipeline.optional_steps.include?(:optional_step)
      refute pipeline.optional_steps.include?(:regular)
    end

    def test_optional_reserved_as_step_name
      assert_raises(ArgumentError) do
        Pipeline.new do
          step :optional, ->(r) { r }, depends_on: :none
        end
      end
    end

    def test_optional_step_has_empty_dependencies
      pipeline = Pipeline.new do
        step :optional_step, ->(r) { r }, depends_on: :optional
      end

      assert_equal [], pipeline.step_dependencies[:optional_step]
    end

    # ===========================================
    # Execution behavior tests
    # ===========================================

    def test_optional_step_not_executed_without_activation
      executed = []

      pipeline = Pipeline.new do
        step :start, ->(r) { executed << :start; r.continue(r.value) }, depends_on: :none
        step :optional_step, ->(r) { executed << :optional_step; r.continue(r.value) }, depends_on: :optional
        step :finish, ->(r) { executed << :finish; r.continue(r.value) }, depends_on: [:start]
      end

      pipeline.call_parallel(Result.new('data'))

      assert_equal [:start, :finish], executed
    end

    def test_optional_step_executed_when_activated
      executed = []

      pipeline = Pipeline.new do
        step :start, ->(r) {
          executed << :start
          r.continue(r.value).activate(:optional_step)
        }, depends_on: :none
        step :optional_step, ->(r) { executed << :optional_step; r.continue(r.value) }, depends_on: :optional
        step :finish, ->(r) { executed << :finish; r.continue(r.value) }, depends_on: [:start]
      end

      pipeline.call_parallel(Result.new('data'))

      assert_includes executed, :optional_step
    end

    def test_router_pattern_activates_one_path
      executed = []

      pipeline = Pipeline.new do
        step :router, ->(r) {
          executed << :router
          case r.value[:type]
          when :pdf then r.continue(r.value).activate(:process_pdf)
          when :image then r.continue(r.value).activate(:process_image)
          else r.continue(r.value).activate(:process_default)
          end
        }, depends_on: :none

        step :process_pdf, ->(r) { executed << :process_pdf; r.continue(r.value) }, depends_on: :optional
        step :process_image, ->(r) { executed << :process_image; r.continue(r.value) }, depends_on: :optional
        step :process_default, ->(r) { executed << :process_default; r.continue(r.value) }, depends_on: :optional
      end

      pipeline.call_parallel(Result.new({ type: :pdf }))

      assert_equal [:router, :process_pdf], executed
    end

    def test_dependency_chain_with_optional_step
      executed = []

      pipeline = Pipeline.new do
        step :a, ->(r) {
          executed << :a
          r.continue(r.value).activate(:b)
        }, depends_on: :none

        step :b, ->(r) { executed << :b; r.continue(r.value) }, depends_on: :optional

        step :c, ->(r) { executed << :c; r.continue(r.value) }, depends_on: [:b]
      end

      pipeline.call_parallel(Result.new('data'))

      assert_equal [:a, :b, :c], executed
    end

    def test_non_activated_optional_dependents_dont_run
      executed = []

      pipeline = Pipeline.new do
        step :a, ->(r) {
          executed << :a
          r.continue(r.value)  # Does NOT activate :b
        }, depends_on: :none

        step :b, ->(r) { executed << :b; r.continue(r.value) }, depends_on: :optional

        step :c, ->(r) { executed << :c; r.continue(r.value) }, depends_on: [:b]
      end

      pipeline.call_parallel(Result.new('data'))

      # Only :a runs, :b is optional and not activated, :c depends on :b so doesn't run
      assert_equal [:a], executed
    end

    def test_multiple_optional_steps_activated
      executed = []

      pipeline = Pipeline.new do
        step :start, ->(r) {
          executed << :start
          r.continue(r.value).activate(:opt_a, :opt_b)
        }, depends_on: :none

        step :opt_a, ->(r) { executed << :opt_a; r.continue(r.value) }, depends_on: :optional
        step :opt_b, ->(r) { executed << :opt_b; r.continue(r.value) }, depends_on: :optional
        step :opt_c, ->(r) { executed << :opt_c; r.continue(r.value) }, depends_on: :optional
      end

      pipeline.call_parallel(Result.new('data'))

      assert_includes executed, :start
      assert_includes executed, :opt_a
      assert_includes executed, :opt_b
      refute_includes executed, :opt_c
    end

    # ===========================================
    # Error cases
    # ===========================================

    def test_activating_unknown_step_raises_error
      pipeline = Pipeline.new do
        step :start, ->(r) {
          r.continue(r.value).activate(:nonexistent_step)
        }, depends_on: :none
      end

      error = assert_raises(ArgumentError) do
        pipeline.call_parallel(Result.new('data'))
      end

      assert_match(/unknown step :nonexistent_step/, error.message)
    end

    def test_activating_non_optional_step_raises_error
      pipeline = Pipeline.new do
        step :start, ->(r) {
          r.continue(r.value).activate(:regular_step)
        }, depends_on: :none

        step :regular_step, ->(r) { r.continue(r.value) }, depends_on: [:start]
      end

      error = assert_raises(ArgumentError) do
        pipeline.call_parallel(Result.new('data'))
      end

      assert_match(/non-optional step :regular_step/, error.message)
    end

    def test_double_activation_is_idempotent
      executed = []

      pipeline = Pipeline.new do
        step :a, ->(r) {
          executed << :a
          r.continue(r.value).activate(:opt).activate(:opt)
        }, depends_on: :none

        step :opt, ->(r) { executed << :opt; r.continue(r.value) }, depends_on: :optional
      end

      # Should not raise, and :opt should only run once
      pipeline.call_parallel(Result.new('data'))

      assert_equal 1, executed.count(:opt)
    end

    def test_activating_already_executed_step_is_ignored
      executed = []

      pipeline = Pipeline.new do
        step :a, ->(r) {
          executed << :a
          r.continue(r.value).activate(:opt)
        }, depends_on: :none

        step :opt, ->(r) { executed << :opt; r.continue(r.value) }, depends_on: :optional

        step :b, ->(r) {
          executed << :b
          # Try to activate :opt again after it's already run
          r.continue(r.value).activate(:opt)
        }, depends_on: [:a, :opt]
      end

      # Should not raise or run :opt twice
      pipeline.call_parallel(Result.new('data'))

      assert_equal 1, executed.count(:opt)
    end

    # ===========================================
    # Halt behavior
    # ===========================================

    def test_halt_stops_execution_with_pending_activations
      executed = []

      pipeline = Pipeline.new do
        step :a, ->(r) {
          executed << :a
          r.halt.activate(:opt)  # Activate but also halt
        }, depends_on: :none

        step :opt, ->(r) { executed << :opt; r.continue(r.value) }, depends_on: :optional
      end

      result = pipeline.call_parallel(Result.new('data'))

      assert_equal [:a], executed
      refute result.continue?
    end

    # ===========================================
    # Parallel execution tests
    # ===========================================

    def test_parallel_steps_can_activate_different_optional_steps
      executed = []

      pipeline = Pipeline.new do
        step :start, ->(r) { executed << :start; r.continue(r.value) }, depends_on: :none

        step :branch_a, ->(r) {
          executed << :branch_a
          r.continue(r.value).activate(:opt_a)
        }, depends_on: [:start]

        step :branch_b, ->(r) {
          executed << :branch_b
          r.continue(r.value).activate(:opt_b)
        }, depends_on: [:start]

        step :opt_a, ->(r) { executed << :opt_a; r.continue(r.value) }, depends_on: :optional
        step :opt_b, ->(r) { executed << :opt_b; r.continue(r.value) }, depends_on: :optional
      end

      pipeline.call_parallel(Result.new('data'))

      assert_includes executed, :opt_a
      assert_includes executed, :opt_b
    end

    def test_activated_optional_steps_run_in_parallel_when_possible
      executed = []
      execution_times = {}

      pipeline = Pipeline.new do
        step :start, ->(r) {
          executed << :start
          r.continue(r.value).activate(:opt_a, :opt_b)
        }, depends_on: :none

        step :opt_a, ->(r) {
          execution_times[:opt_a] = Time.now
          sleep 0.05
          executed << :opt_a
          r.continue(r.value)
        }, depends_on: :optional

        step :opt_b, ->(r) {
          execution_times[:opt_b] = Time.now
          sleep 0.05
          executed << :opt_b
          r.continue(r.value)
        }, depends_on: :optional
      end

      start_time = Time.now
      pipeline.call_parallel(Result.new('data'))
      total_time = Time.now - start_time

      # Both optional steps should run
      assert_includes executed, :opt_a
      assert_includes executed, :opt_b

      # If they ran in parallel, total time should be less than 0.1s
      # (with some margin for overhead)
      assert total_time < 0.15, "Expected parallel execution but took #{total_time}s"
    end

    # ===========================================
    # Complex workflow tests
    # ===========================================

    def test_conditional_workflow_with_multiple_branches
      executed = []

      pipeline = Pipeline.new do
        step :validate, ->(r) {
          executed << :validate
          if r.value[:premium]
            r.continue(r.value).activate(:premium_processing)
          else
            r.continue(r.value).activate(:standard_processing)
          end
        }, depends_on: :none

        step :premium_processing, ->(r) {
          executed << :premium_processing
          r.continue(r.value).activate(:premium_extras)
        }, depends_on: :optional

        step :premium_extras, ->(r) {
          executed << :premium_extras
          r.continue(r.value)
        }, depends_on: :optional

        step :standard_processing, ->(r) {
          executed << :standard_processing
          r.continue(r.value)
        }, depends_on: :optional

        step :finalize, ->(r) {
          executed << :finalize
          r.continue(r.value)
        }, depends_on: [:validate]
      end

      # Test premium path
      executed.clear
      pipeline.call_parallel(Result.new({ premium: true }))
      assert_includes executed, :premium_processing
      assert_includes executed, :premium_extras
      refute_includes executed, :standard_processing

      # Test standard path
      executed.clear
      pipeline.call_parallel(Result.new({ premium: false }))
      assert_includes executed, :standard_processing
      refute_includes executed, :premium_processing
    end

    def test_activated_step_can_activate_other_steps
      executed = []

      pipeline = Pipeline.new do
        step :start, ->(r) {
          executed << :start
          r.continue(r.value).activate(:step_a)
        }, depends_on: :none

        step :step_a, ->(r) {
          executed << :step_a
          r.continue(r.value).activate(:step_b)
        }, depends_on: :optional

        step :step_b, ->(r) {
          executed << :step_b
          r.continue(r.value)
        }, depends_on: :optional
      end

      pipeline.call_parallel(Result.new('data'))

      assert_equal [:start, :step_a, :step_b], executed
    end
  end
end
