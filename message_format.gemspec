# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'message_format/version'

Gem::Specification.new do |spec|
  spec.name          = "message_format"
  spec.version       = MessageFormat::VERSION
  spec.authors       = ["Andy VanWagoner"]
  spec.email         = ["andy@instructure.com"]
  spec.summary       = %q{Parse and format i18n messages using ICU MessageFormat patterns}
  spec.description   = %q{Parse and format i18n messages using ICU MessageFormat patterns, including simple placeholders, number and date placeholders, and selecting among submessages for gender and plural arguments.}
  spec.homepage      = "https://github.com/thetalecrafter/message-format-rb"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "twitter_cldr", "~> 3.1"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.0"
end
