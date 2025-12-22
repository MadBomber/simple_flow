#
# SimpleFlow is a modular, configurable processing framework designed for constructing and
# managing sequences of operations in a streamlined and efficient manner. It allows for the easy
# integration of middleware components to augment functionality, such as logging and
# instrumentation, ensuring that actions within the pipeline are executed seamlessly. By
# defining steps as callable objects, SimpleFlow facilitates the customized processing of data,
# offering granular control over the flow of execution and enabling conditional continuation
# based on the outcome of each step. This approach makes SimpleFlow ideal for complex workflows
# where the orchestration of tasks, error handling, and context management are crucial.
#

require 'delegate'
require 'logger'

require_relative 'simple_flow/version'
require_relative 'simple_flow/result'
require_relative 'simple_flow/middleware'
require_relative 'simple_flow/dependency_graph'
require_relative 'simple_flow/dependency_graph_visualizer'
require_relative 'simple_flow/parallel_executor'
require_relative 'simple_flow/pipeline'

module SimpleFlow
end
