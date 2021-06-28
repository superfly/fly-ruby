Gem::Specification.new do |spec|
  spec.name = "fly-rails"
  spec.version = "0.0.1"
  spec.authors = ["Joshua Sierles"]
  spec.description = spec.summary = "Enhance Rails apps for deployment within Fly.io"
  spec.email = "joshua@hey.com"

  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 2.4"
  spec.files = `git ls-files | grep -Ev '^(test)'`.split("\n")

  spec.add_dependency "railties", ">= 5.0"
end
