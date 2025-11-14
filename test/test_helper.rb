# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
    add_filter '/vendor/'
    enable_coverage :branch
    minimum_coverage line: 90, branch: 80
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "simple_flow"

require "minitest/autorun"
