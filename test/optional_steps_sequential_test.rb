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
