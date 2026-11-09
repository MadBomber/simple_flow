require_relative 'test_helper'
require 'stringio'

module SimpleFlow
  module MiddleWare
    class TestLogging < Minitest::Test
      def setup
        @callable = ->(result) { "Processed: #{result}" }
        @logger = Logger.new($stdout)
        @logging_middleware = Logging.new(@callable, @logger)
      end
            
        def test_call_logs_correctly
          result = "initial"
          output = StringIO.new
          logger = Logger.new(output)
          
          # Make sure the middleware uses this logger
          @logging_middleware = Logging.new(@callable, logger)
          
          processed_result = @logging_middleware.call(result)
          
          # Check if the expected log messages are present in the output
          assert_match(/Before call/, output.string)
          assert_match(/After call/, output.string)
          assert_equal "Processed: initial", processed_result
      end

      def test_pipeline_use_middleware_accepts_logger_keyword
        output = StringIO.new
        logger = Logger.new(output)
        pipeline = SimpleFlow::Pipeline.new do
          use_middleware SimpleFlow::MiddleWare::Logging, logger: logger
          step ->(result) { result.continue(result.value + 1) }
        end

        final = pipeline.call(SimpleFlow::Result.new(1))

        assert_equal 2, final.value
        assert_match(/Before call/, output.string)
        assert_match(/After call/, output.string)
      end

      def test_initialize_accepts_logger_keyword
        output = StringIO.new
        Logging.new(@callable, logger: Logger.new(output)).call('x')

        assert_match(/Before call/, output.string)
      end

      def test_logger_keyword_wins_over_positional_logger
        keyword_output = StringIO.new
        positional_output = StringIO.new
        middleware = Logging.new(@callable, Logger.new(positional_output), logger: Logger.new(keyword_output))
        middleware.call('x')

        assert_match(/Before call/, keyword_output.string)
        assert_empty positional_output.string
      end
    end

    class TestInstrumentation < Minitest::Test
      def setup
        @callable = ->(result) { "Processed: #{result}" }
        @instrumentation_middleware = Instrumentation.new(@callable, api_key: "API_KEY")
      end

      def test_call_instruments_correctly
        result = "initial"
        output = StringIO.new
        $stdout = output
        
        processed_result = @instrumentation_middleware.call(result)
        
        $stdout = STDOUT
        assert_match(/Instrumentation: API_KEY took/, output.string)
        assert_equal "Processed: initial", processed_result
      end
    end
  end
end
