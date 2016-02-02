require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'

task default: :rubocop

desc 'Run RuboCop against the source code.'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
  task.options << '--display-cop-names'
  task.options << '--display-style-guide'
end
