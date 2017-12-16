$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "csv_import_form/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "csv_import_form"
  s.version     = CsvImportForm::VERSION
  s.authors     = ["Toshihisa KATO"]
  s.email       = ["toshihk@gmail.com"]
  s.homepage    = "https://github.com/toshih-k/rails_csv_import_form"
  s.summary     = "Utility model for import csv file to activerecord based model."
  s.description = "CSVファイルからActiveRecordへデータをインポートするためのユーティリティモデル"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 4.2"

  s.add_development_dependency "sqlite3"
end
