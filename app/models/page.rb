class Page < ActiveRecord::Base
  validates :title, presence: true, uniqueness: true
  validates :url, presence: true, uniqueness: true
  validates :content, presence: true
  validates :language, inclusion: { in: %w(en da), message: "%{value} is not a valid language" }
end