Gem::Specification.new do |s|
  s.name = 'sequel-uow'
  s.version = '0.0.1'
  s.platform = 'ruby'
  s.required_ruby_version = '~> 1.9'

  s.summary = 'A Unit of Work pattern on top of Sequel (experimental)'
  s.description = 'This gem provides offline transaction management for Sequel::Model objects'
  s.homepage = 'http://github.com/nandosola/sequel-uow'

  s.authors = ['Nando Sola']
  s.email = ['nando@abstra.cc']

  s.licenses << 'New BSD License'
  s.files = Dir['./LICENSE']
  s.files += Dir['lib/**/*']

  s.add_runtime_dependency 'sequel', '~> 4.1.0'

  s.add_development_dependency 'rake', '~> 0.9.6'
  s.add_development_dependency 'sqlite3', '~> 1.3.7'
  s.add_development_dependency 'rspec', '~> 2.14.1'

  s.require_path = 'lib'

end
