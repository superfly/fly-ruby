require_relative 'lib/fly-ruby/version'

Gem::Specification.new do |spec|
  spec.name = "fly-ruby"
  spec.version = Fly::VERSION
  spec.authors = ["Joshua Sierles"]
  spec.homepage = "https://github.com/superfly/fly-ruby"
  spec.summary = "Augment Ruby web apps for deployment in Fly.io"
  spec.description = "Automate the work requied to run Ruby apps against region-local databases on Fly.io"
  spec.email = "joshua@hey.com"
  spec.licenses = "BSD-3-Clause"
  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 2.4"
  spec.files = `git ls-files | grep -Ev '^(test)'`.split("\n")

  spec.add_dependency "rack", "~> 2.0"
end
