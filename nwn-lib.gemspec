# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ["Bernhard Stoeckner"]
  gem.email         = ["n@e-ix.net"]
  gem.description   = %q{Neverwinter Nights 1/2 file formats ruby library}
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/niv/nwn-lib"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "nwn-lib"
  gem.require_paths = ["lib"]
  gem.version       = "0.6.1"
  gem.required_ruby_version = '>= 1.9.3'
  gem.license       = 'MIT'
end
