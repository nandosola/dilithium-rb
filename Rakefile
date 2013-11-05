require 'bundler/setup'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.ruby_opts = '-Ilib -Ispec'
  spec.rspec_opts = %w{--color --format nested}
end
