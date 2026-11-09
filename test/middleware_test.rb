require 'minitest/autorun'
require 'logger'
require_relative '../lib/simple_flow'

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
