# db/migrate.rb
require "sequel"

db = Sequel.connect(ENV.fetch("DATABASE_URL"))
Sequel.extension :migration

migrations_dir = File.expand_path("../migrations", __dir__)
Sequel::Migrator.run(db, migrations_dir)

puts "[db] migrations OK"
