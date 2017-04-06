require 'bundler/setup'
require 'bundler/gem_tasks'
require 'cucumber'
require 'cucumber/rake/task'
require 'rubocop/rake_task'

desc 'Run all required tests - simply run `rake`'
task default: %w[rubocop features]

Cucumber::Rake::Task.new(:features)

# desc 'Run RuboCop against the source code.'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
  task.options << '--display-cop-names'
  task.options << '--display-style-guide'
end
