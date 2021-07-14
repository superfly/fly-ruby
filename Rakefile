require "bundler/gem_tasks"
require "rake/testtask"
require_relative "lib/fly-ruby/version"

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

task :publish do
  version = Fly::VERSION
  puts "Publishing fly-ruby #{version}..."
  sh "git tag -f v#{version}"
  sh "gem build"
  sh "gem push fly-ruby-#{version}.gem"
  sh "git push --tags"
end
