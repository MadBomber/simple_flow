# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
  # Load test_helper before any tests run to ensure SimpleCov starts first
  t.ruby_opts << "-rtest_helper"
end

task default: :test
