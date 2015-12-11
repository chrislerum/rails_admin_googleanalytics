$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "rails_admin_googleanalytics/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "rails_admin_googleanalytics"
  s.version     = RailsAdminGoogleanalytics::VERSION
  s.authors     = ["Richard Peng"]
  s.email       = ["richard@richardpeng.com"]
  s.homepage    = "http://richardpeng.com"
  s.summary     = "Google Analytics tab for Rails Admin"
  s.description = "Show some basic statistics from within the Rails Admin interface."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", "= 4.2.4"
  s.add_dependency "google-api-client", ">= 0.5"
end
