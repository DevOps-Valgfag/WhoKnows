require 'sqlite3'
require 'bcrypt'

module DatabaseHelper
  def self.setup_test_database
    db_path = File.join(File.dirname(__FILE__), '../../whoknows.db')
    
    # Remove existing test database if it exists
    File.delete(db_path) if File.exist?(db_path)
    
    # Create new database
    db = SQLite3::Database.new(db_path)
    
    # Create users table
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL,
        password TEXT NOT NULL,
        must_change_password INTEGER DEFAULT 0
      );
    SQL
    
    # Create pages table
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        language TEXT DEFAULT 'en'
      );
    SQL
    
    # Seed with test data
    seed_test_data(db)
    
    db.close
  end
  
  def self.seed_test_data(db)
    # Add some test pages for search functionality
    db.execute("INSERT INTO pages (title, content, language) VALUES (?, ?, ?)", 
               ['MATLAB Introduction', 'MATLAB is a programming language for technical computing.', 'en'])
    db.execute("INSERT INTO pages (title, content, language) VALUES (?, ?, ?)", 
               ['Python Guide', 'Python is a high-level programming language.', 'en'])
    db.execute("INSERT INTO pages (title, content, language) VALUES (?, ?, ?)", 
               ['Ruby Tutorial', 'Ruby is a dynamic, open source programming language.', 'en'])
    
    # Add a test user
    hashed_password = BCrypt::Password.create('password123')
    db.execute("INSERT INTO users (username, email, password, must_change_password) VALUES (?, ?, ?, ?)",
               ['testuser', 'test@example.com', hashed_password, 0])
  end
  
  def self.cleanup_test_database
    db_path = File.join(File.dirname(__FILE__), '../../whoknows.db')
    File.delete(db_path) if File.exist?(db_path)
  end
end
