class Contact < ApplicationRecord
  FIELDS = %i[name organization email phone address notes].freeze
  belongs_to :user
  normalizes :name, :organization, :phone, :address, :notes, with: ->(value) { value.to_s.strip }
  normalizes :email, with: ->(value) { value.to_s.strip.downcase }
  validates :name, presence: true, length: { maximum: 200 }
  validates :organization, :email, length: { maximum: 250 }
  validates :phone, length: { maximum: 80 }
  validates :address, length: { maximum: 4000 }
  validates :notes, length: { maximum: 10_000 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  scope :searching, ->(query) {
    where(%q(name LIKE :q ESCAPE '\' OR organization LIKE :q ESCAPE '\' OR email LIKE :q ESCAPE '\' OR phone LIKE :q ESCAPE '\'), q: "%#{sanitize_sql_like(query.to_s.strip)}%") if query.present?
  }

  def recipient_props
    as_json(only: %i[id name organization email phone address]).merge(
      recipient: organization.presence || name, contact: email.present? ? "#{name} <#{email}>" : name
    )
  end
end
