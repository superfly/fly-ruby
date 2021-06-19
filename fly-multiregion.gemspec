Gem::Specification.new do |spec|
  spec.name = "fly-multiregion"
  spec.version = "0.0.1"
  spec.authors = ["Joshua Sierles"]
  spec.description = spec.summary = "Automate redirecting web requests to a writeable region on Fly.io"
  spec.email = "joshua@hey.com"

  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.4'
  spec.files = `git ls-files | grep -Ev '^(spec|benchmarks|examples)'`.split("\n")

  spec.add_dependency "railties", ">= 5.0"
end
