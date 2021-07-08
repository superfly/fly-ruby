require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*.rb']
  t.verbose = true
end

desc "Run tests"
task default: :test


task :top do
  puts Rake.application.top_level_tasks
end
