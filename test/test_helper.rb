# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  skip '/test/'
  skip '/examples/'
  skip '/benchmarks/'
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simple_flow"

require "minitest/autorun"
