module SimpleFlow
  ##
  # This class represents the result of an operation within a simple flow system.
  #
  # It encapsulates the operation's outcome (value), contextual data (context),
  # and any errors occurred during the operation (errors). Its primary purpose
  # is to facilitate flow control and error handling in a clean and predictable
  # manner. The class provides mechanisms to update context and errors, halt 
  # the flow, and conditionally continue based on the operation state. This
  # promotes creating a chainable, fluent interface for managing operation
  # results in complex processes or workflows.
  #
  class Result
    # The outcome of the operation.
    attr_reader :value

    # Contextual data related to the operation.
    attr_reader :context

    # Errors occurred during the operation.
    attr_reader :errors

    # Steps that have been activated for dynamic execution.
    attr_reader :activated_steps

    # Initializes a new Result instance.
    # @param value [Object] the outcome of the operation.
    # @param context [Hash, optional] contextual data related to the operation.
    # @param errors [Hash, optional] errors occurred during the operation.
    # @param activated_steps [Array<Symbol>, optional] steps activated for dynamic execution.
    def initialize(value, context: {}, errors: {}, activated_steps: [])
      @value = value
      @context = context
      @errors = errors
      @activated_steps = activated_steps
      @continue = true
    end

    # Adds or updates context to the result.
    # @param key [Symbol] the key to store the context under.
    # @param value [Object] the value to store.
    # @return [Result] a new Result instance with updated context.
    def with_context(key, value)
      result = self.class.new(@value, context: @context.merge(key => value), errors: @errors, activated_steps: @activated_steps)
      result.instance_variable_set(:@continue, @continue)
      result
    end

    # Adds an error message under a specific key.
    # If the key already exists, it appends the message to the existing errors.
    # @param key [Symbol] the key under which the error should be stored.
    # @param message [String] the error message.
    # @return [Result] a new Result instance with updated errors.
    def with_error(key, message)
      result = self.class.new(@value, context: @context, errors: @errors.merge(key => [*@errors[key], message]), activated_steps: @activated_steps)
      result.instance_variable_set(:@continue, @continue)
      result
    end

    # Halts the flow, optionally updating the result's value.
    # @param new_value [Object, nil] the new value to set, if any.
    # @return [Result] a new Result instance with continue set to false.
    def halt(new_value = nil)
      result = new_value ? with_value(new_value) : self.class.new(@value, context: @context, errors: @errors, activated_steps: @activated_steps)
      result.instance_variable_set(:@continue, false)
      result
    end

    # Continues the flow, updating the result's value.
    # @param new_value [Object] the new value to set.
    # @return [Result] a new Result instance with the new value.
    def continue(new_value)
      with_value(new_value)
    end

    # Checks if the operation should continue.
    # @return [Boolean] true if the operation should continue, else false.
    def continue?
      @continue
    end

    # Activates optional steps for dynamic execution.
    # @param step_names [Symbol, Array<Symbol>] one or more step names to activate.
    # @return [Result] a new Result instance with the steps added to activated_steps.
    def activate(*step_names)
      new_activated = @activated_steps + step_names.flatten
      result = self.class.new(@value, context: @context, errors: @errors, activated_steps: new_activated)
      result.instance_variable_set(:@continue, @continue)
      result
    end

    private

    # Creates a new Result instance with updated value.
    # @param new_value [Object] the new value for the result.
    # @return [Result] a new Result instance.
    def with_value(new_value)
      result = self.class.new(new_value, context: @context, errors: @errors, activated_steps: @activated_steps)
      result.instance_variable_set(:@continue, @continue)
      result
    end
  end
end
