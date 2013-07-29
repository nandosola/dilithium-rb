require 'bundler/setup'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/spec_base.rb'
  spec.ruby_opts = '-Ilib -Ispec'
  spec.rspec_opts = %w{--color --format nested}
end
