$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "enju_trunk_ndl_statistics/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "enju_trunk_ndl_statistics"
  s.version     = EnjuTrunkNdlStatistics::VERSION
  s.authors     = ["Emiko Tamiya"]
  s.email       = ["tamiya.emiko@miraitsystems.jp"]
  s.homepage    = "https://github.com/nakamura-akifumi/enju_trunk"
  s.summary     = "EnjuTrunkNdlStatistics: annual statistics report for NDL branches"
  s.description = ""

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.8"
  # s.add_dependency "jquery-rails"

end
