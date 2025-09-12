class CreatePages < ActiveRecord::Migration[7.0]
  def change
    create_table :pages do |t|
      # In ActiveRecord, an 'id' primary key is created automatically.
      # We will make 'title' unique but not the primary key.
      t.string :title, null: false
      t.string :url, null: false
      t.string :language, null: false, default: 'en'
      t.text :content, null: false
      t.timestamp :last_updated
    end
    add_index :pages, :title, unique: true
    add_index :pages, :url, unique: true
  end
end