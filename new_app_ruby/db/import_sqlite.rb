# db/import_sqlite.rb
require 'dotenv/load'
require 'sequel'
require 'sqlite3'

sqlite_path = ENV.fetch('SQLITE_PATH', '/import/whoknows.db')
pg_url      = ENV.fetch('DATABASE_URL')

puts "[import] reading sqlite from: #{sqlite_path}"
puts "[import] writing to postgres: #{pg_url}"

# SQLite connection (Sequel)
sqlite = Sequel.sqlite(sqlite_path)
pg     = Sequel.connect(pg_url)

# Ensure tables exist (migrations should have run already)
unless pg.table_exists?(:users) && pg.table_exists?(:pages)
  abort '[import] postgres tables missing. Run migrations first.'
end

pg.transaction do
  # USERS
  if sqlite.table_exists?(:users)
    users = sqlite[:users].all
    puts "[import] users rows: #{users.size}"

    # Clear postgres tables first (optional but typical for a one-time import)
    pg[:users].delete

    users.each do |u|
      pg[:users].insert(
        id: u[:id],
        username: u[:username],
        email: u[:email],
        password: u[:password],
        must_change_password: (u[:must_change_password] || 0).to_i
      )
    end

    # reset sequence so next insert gets correct id
    pg.run("SELECT setval(pg_get_serial_sequence('users','id'), (SELECT COALESCE(MAX(id),1) FROM users))")
  else
    puts '[import] sqlite has no users table, skipping'
  end

  # PAGES
  if sqlite.table_exists?(:pages)
    pages = sqlite[:pages].all
    puts "[import] pages rows: #{pages.size}"

    # ryd først (hurtigt + reset id)
    pg.run('TRUNCATE TABLE pages RESTART IDENTITY CASCADE')

    pages.each do |p|
      pg[:pages].insert(
        title: p[:title],
        url: p[:url],
        language: p[:language] || 'en',
        last_updated: p[:last_updated],
        content: (p[:content] || '').strip
      )
    end
  else
    puts '[import] sqlite has no pages table, skipping'
  end
end

puts '[import] DONE'
