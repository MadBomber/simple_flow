# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  # Optional steps run only when activated under `call` and
  # `call_parallel(strategy: :explicit)`, as they already do under the
  # dependency-graph strategy (issue #45)
  class OptionalStepsSequentialTest < Minitest::Test
    # A step that records its name in +ran+ and sets the value to its name
    def recorder(ran, name)
      lambda { |r|
        ran << name
        r.continue(name)
      }
    end

    def build_router(ran)
      classify = recorder(ran, :classify)
      pdf = recorder(ran, :pdf)
      image = recorder(ran, :image)
      Pipeline.new do
        step :classify, ->(r) { classify.call(r).activate(:pdf) }, depends_on: :none
        step :pdf, pdf, depends_on: :optional
        step :image, image, depends_on: :optional
      end
    end

    def test_call_skips_unactivated_optional_steps
      ran = []
      result = build_router(ran).call(Result.new(1))

      assert_equal %i[classify pdf], ran
      assert_equal :pdf, result.value
    end

    def test_explicit_strategy_skips_unactivated_optional_steps
      ran = []
      result = build_router(ran).call_parallel(Result.new(1), strategy: :explicit)

      assert_equal %i[classify pdf], ran
      assert_equal :pdf, result.value
    end

    def test_call_runs_optional_step_activated_on_the_input
      ran = []
      extra = recorder(ran, :extra)
      pipeline = Pipeline.new do
        step :extra, extra, depends_on: :optional
      end

      assert_equal :extra, pipeline.call(Result.new(1).activate(:extra)).value
      assert_equal %i[extra], ran
    end

    # Issue #51: all three runners reject an unknown or non-optional activation
    def test_every_runner_rejects_activating_an_unknown_step
      pipeline = Pipeline.new do
        step :router, ->(r) { r.activate(:nope).continue(r.value) }, depends_on: :none
      end

      each_runner(pipeline) do |run|
        error = assert_raises(ArgumentError) { run.call(Result.new(1)) }
        assert_equal 'Step :router attempted to activate unknown step :nope', error.message
      end
    end

    def test_every_runner_rejects_activating_a_non_optional_step
      pipeline = Pipeline.new do
        step :router, ->(r) { r.activate(:regular).continue(r.value) }, depends_on: :none
        step :regular, ->(r) { r.continue(r.value) }, depends_on: [:router]
      end

      each_runner(pipeline) do |run|
        error = assert_raises(ArgumentError) { run.call(Result.new(1)) }
        assert_match(/\AStep :router attempted to activate non-optional step :regular\./, error.message)
      end
    end

    def test_unnamed_steps_and_parallel_blocks_are_named_in_the_error
      pipeline = Pipeline.new do
        step :start, ->(r) { r.continue(r.value) }, depends_on: :none
        step ->(r) { r.activate(:nope) }
      end
      error = assert_raises(ArgumentError) { pipeline.call(Result.new(1)) }
      assert_equal 'An unnamed step attempted to activate unknown step :nope', error.message

      pipeline = Pipeline.new do
        step :start, ->(r) { r.continue(r.value) }, depends_on: :none
        parallel { step ->(r) { r.activate(:nope) } }
      end
      error = assert_raises(ArgumentError) { pipeline.call(Result.new(1)) }
      assert_equal 'A parallel block attempted to activate unknown step :nope', error.message
    end

    def each_runner(pipeline)
      yield pipeline.method(:call)
      yield ->(r) { pipeline.call_parallel(r) }
      yield ->(r) { pipeline.call_parallel(r, strategy: :explicit) }
    end

    # Issue #50: a step that depends on a skipped optional step is skipped too
    def build_dependent_pipeline
      Pipeline.new do
        step :start, ->(r) { r.continue(r.value) }, depends_on: :none
        step :opt, ->(r) { r.with_context(:opt, true).continue(r.value) }, depends_on: :optional
        step :after_opt, ->(r) { r.with_context(:after_opt, true).continue(r.value) }, depends_on: [:opt]
        parallel :after_after, depends_on: [:after_opt] do
          step :aa, ->(r) { r.with_context(:aa, true).continue(r.value) }
        end
        step :final, ->(r) { r.with_context(:final, true).continue(r.value) }, depends_on: [:start]
      end
    end

    def test_every_runner_skips_dependents_of_an_unactivated_optional_step
      pipeline = build_dependent_pipeline
      input = Result.new(1)

      assert_equal({ final: true }, pipeline.call(input).context)
      assert_equal({ final: true }, pipeline.call_parallel(input).context)
      assert_equal({ final: true }, pipeline.call_parallel(input, strategy: :explicit).context)
    end

    def test_dependents_of_an_activated_optional_step_run
      pipeline = build_dependent_pipeline
      input = Result.new(1).activate(:opt)

      assert_equal({ opt: true, after_opt: true, aa: true, final: true }, pipeline.call(input).context)
      assert_equal({ opt: true, after_opt: true, aa: true, final: true },
                   pipeline.call_parallel(input, strategy: :explicit).context)
    end

    def test_skip_optional_step_predicate
      pipeline = build_router([])
      optional = { name: :pdf, type: :named }
      regular = { name: :classify, type: :named }

      assert pipeline.send(:skip_optional_step?, optional, Result.new(1))
      refute pipeline.send(:skip_optional_step?, optional, Result.new(1).activate(:pdf))
      refute pipeline.send(:skip_optional_step?, regular, Result.new(1))
      refute pipeline.send(:skip_optional_step?, { type: :unnamed }, Result.new(1))
    end

    def test_skip_optional_step_with_raw_input_skips_optional_steps
      pipeline = build_router([])

      assert pipeline.send(:skip_optional_step?, { name: :pdf, type: :named }, 1)
      refute pipeline.send(:skip_optional_step?, { name: :classify, type: :named }, 1)
    end
  end
end
