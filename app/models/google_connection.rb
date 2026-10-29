class GoogleConnection < ApplicationRecord
  encrypts :refresh_token
  validates :email, :refresh_token, presence: true
end
