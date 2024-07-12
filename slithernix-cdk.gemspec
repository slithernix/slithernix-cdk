# frozen_string_literal: true

desc = [
  'This gem provides a Ruby port of the CDK (Curses Development Kit),',
  'a library for drawing TUI widgets. It has been updated and re-factored',
  'to work with modern Ruby.'
].join(' ')

Gem::Specification.new do |spec|
  spec.required_ruby_version = '3.2.0'

  spec.name          = 'slithernix-cdk'
  spec.version       = '0.0.1'
  spec.authors       = ['Snake Blitzken']
  spec.email         = ['cdk@slithernix.com']

  spec.summary       = 'Curses Development Kit'
  spec.description   = desc
  spec.homepage      = 'https://github.com/slithernix/slithernix-cdk'
  spec.license       = 'BSD-3-Clause'

  spec.files         = Dir['lib/**/*.rb'] + ['README.md', 'COPYING']
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'curses', '~> 1.4'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
