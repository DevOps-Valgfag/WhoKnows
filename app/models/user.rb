require 'bcrypt'

class User < ActiveRecord::Base
  # This line adds methods to set and authenticate against a BCrypt password.
  # It requires a 'password_digest' column in the database.
  has_secure_password

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: /\A[^@\s]+@[^@\s]+\z/ }
  validates :password, presence: true, on: :create
end