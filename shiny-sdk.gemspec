Gem::Specification.new do |s|
  s.name        = 'shiny-sdk'
  s.version     = '1.0.1'
  s.date        = `git log --pretty="%ai" -n 1`.split(" ").first
  s.summary     = "Shiny SDK"
  s.description = "Shiny Ruby SDK"
  s.authors     = ["Koell"]
  s.email       = 'i@wug.moe'
  s.files       = `git ls-files -z`.split("\0")
  s.homepage    = 'https://shiny.kotori.moe'
  s.metadata = {
    "source_code_uri" => "https://github.com/Shiny-Project/Shiny-Ruby-SDK/"
  }
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.6.0'
end