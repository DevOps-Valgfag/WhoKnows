# migrations/001_create_tables.rb
Sequel.migration do
  change do
    create_table?(:users) do
      primary_key :id
      String  :username, null: false
      String  :email,    null: false
      String  :password, null: false
      Integer :must_change_password, null: false, default: 0

      index :username, unique: true
      index :email, unique: true
    end

    create_table?(:pages) do
      primary_key :id
      String :title,    null: false
      Text   :content,  null: false
      String :language, null: false, default: "en"

      index :language
    end
  end
end
