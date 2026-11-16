class ApiKey < ApplicationRecord
  belongs_to :user
  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  def self.issue!(user:, name:, write_access: false)
    token = "im_#{SecureRandom.urlsafe_base64(32)}"
    key = create!(user: user, name: name, write_access: write_access, token_digest: Digest::SHA256.hexdigest(token))
    [ key, token ]
  end
end
