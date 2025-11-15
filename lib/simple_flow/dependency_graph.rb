# frozen_string_literal: true

require 'tsort'

module SimpleFlow
  ##
  # DependencyGraph manages dependencies between pipeline steps and determines
  # which steps can be executed in parallel. This is adapted from the dagwood gem
  # (https://github.com/rewindio/dagwood) to work with SimpleFlow pipelines.
  #
  # Example:
  #   graph = SimpleFlow::DependencyGraph.new(
  #     fetch_user: [],
  #     fetch_orders: [:fetch_user],
  #     fetch_products: [:fetch_user],
  #     calculate_total: [:fetch_orders, :fetch_products]
  #   )
  #
  #   graph.parallel_order
  #   # => [[:fetch_user], [:fetch_orders, :fetch_products], [:calculate_total]]
  #
  class DependencyGraph
    include TSort

    attr_reader :dependencies

    # @param dependencies [Hash]
    #   A hash of the form { step1: [:step2, :step3], step2: [:step3], step3: []}
    #   would mean that "step1" depends on step2 and step3, step2 depends on step3
    #   and step3 has no dependencies. Nil and missing values will be converted to [].
    def initialize(dependencies)
      @dependencies = Hash.new([]).merge(dependencies.transform_values { |v| v.nil? ? [] : Array(v).sort })
    end

    # Returns steps in topological order (dependencies first)
    # @return [Array] ordered list of step names
    def order
      @order ||= tsort
    end

    # Returns steps in reverse topological order
    # @return [Array] reverse ordered list of step names
    def reverse_order
      @reverse_order ||= order.reverse
    end

    # Groups steps that can be executed in parallel.
    # Steps can run in parallel if:
    #   1) They have the exact same dependencies OR
    #   2) All of a step's dependencies have been resolved in previous groups
    #
    # @return [Array<Array>] array of groups, where each group can run in parallel
    def parallel_order
      groups = []
      ungrouped_dependencies = order.dup

      until ungrouped_dependencies.empty?
        # Start this group with the first dependency we haven't grouped yet
        group_starter = ungrouped_dependencies.delete_at(0)
        group = [group_starter]

        ungrouped_dependencies.each do |ungrouped_dependency|
          same_priority = @dependencies[ungrouped_dependency].all? do |sub_dependency|
            groups.reduce(false) { |found, g| found || g.include?(sub_dependency) }
          end

          group << ungrouped_dependency if same_priority
        end

        # Remove dependencies we managed to group
        ungrouped_dependencies -= group

        groups << group.sort
      end

      groups
    end

    # Generate a subgraph starting at the given node
    # @param node [Symbol] the starting node
    # @return [DependencyGraph] a new graph containing only the node and its dependencies
    def subgraph(node)
      return self.class.new({}) unless @dependencies.key? node

      # Add the given node and its dependencies to our hash
      hash = {}
      hash[node] = @dependencies[node]

      # For every dependency of the given node, recursively create a subgraph and merge it into our result
      @dependencies[node].each { |dep| hash.merge! subgraph(dep).dependencies }

      self.class.new hash
    end

    # Returns a new graph containing all dependencies from this graph and the given graph.
    # If both graphs depend on the same item, but that item's sub-dependencies differ, the
    # resulting graph will depend on the union of both.
    # @param other [DependencyGraph] another dependency graph
    # @return [DependencyGraph] merged graph
    def merge(other)
      all_dependencies = {}

      (dependencies.keys | other.dependencies.keys).each do |key|
        all_dependencies[key] = dependencies[key] | other.dependencies[key]
      end

      self.class.new all_dependencies
    end

    private

    def tsort_each_child(node, &block)
      @dependencies.fetch(node, []).each(&block)
    end

    def tsort_each_node(&block)
      @dependencies.each_key(&block)
    end
  end
end
