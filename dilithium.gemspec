Gem::Specification.new do |s|
  s.name = 'dilithium'
  s.version = '0.0.2'
  s.platform = 'ruby'
  s.required_ruby_version = '~> 1.9'

  s.summary = 'A tiny framework to power your enterprise-ish stuff in Ruby'
  s.description = 'Manage persistence-agnostic domain models and decoupled transactions'
  s.homepage = 'http://github.com/nandosola/dilithium-rb'

  s.authors = ['Nando Sola', 'Mario Camou']
  s.email = ['nando@robotchrist.com', 'mcamou@tecnoguru.com']

  s.licenses << 'New BSD License'
  s.files = Dir['./LICENSE']
  s.files += Dir['lib/**/*']

  s.add_runtime_dependency 'sequel', '~> 4.6.0'
  s.add_runtime_dependency 'openwferu-kotoba', '~> 0.9.9'

  s.add_development_dependency 'rake', '~> 10.1.0'
  s.add_development_dependency 'sqlite3', '~> 1.3.8'
  s.add_development_dependency 'rspec', '~> 2.14.1'
  s.add_development_dependency 'bcrypt', '~> 3.1.7'

  s.require_path = 'lib'

end
