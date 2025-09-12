# This file should contain all the record creation needed to seed the database with its default values.

# Create a default user. The password is 'password'.
# Bcrypt will securely hash this for us.
User.find_or_create_by!(username: 'admin') do |user|
    user.email = 'keamonk1@stud.kea.dk'
    user.password = 'password'
    user.password_confirmation = 'password'
end

puts "Database seeded with admin user."