# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  add_filter '/test/'
  add_filter '/examples/'
  add_filter '/benchmarks/'
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simple_flow"

require "minitest/autorun"
