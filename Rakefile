require "bundler/gem_tasks"

task :default => :test

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib/elastic'
  test.test_files = FileList['test/integration/*_test.rb']
  test.verbose = true
  #test.warning = true
end

