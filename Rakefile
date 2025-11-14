# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  # RuboCop not available
end

desc "Run tests with coverage"
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['test'].execute
end

task default: %i[test rubocop]
