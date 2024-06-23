Gem::Specification.new do |spec|
  spec.name          = "slithernix-cdk"
  spec.version       = "0.0.1"
  spec.authors       = ["Snake Blitzken"]
  spec.email         = ["cdk@slithernix.com"]

  spec.summary       = "Curses Development Kit"
  spec.description   = "This gem provides a Ruby port of the CDK (Curses Development Kit) library, fixed for compatibility with modern Ruby versions."
  spec.homepage      = "https://github.com/slithernix/slithernix-cdk"
  spec.license       = "BSD-3-Clause"

  spec.files         = Dir["lib/**/*.rb"] + ["README.md", "COPYING"]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "curses", "~> 1.4"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.64"
end

