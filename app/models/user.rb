class User < ApplicationRecord
  has_many :invoice_drafts, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
