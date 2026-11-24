class OfficialPaymentPrivateNote < ApplicationRecord
  belongs_to :official_payment
  belongs_to :user

  encrypts :private_note
  normalizes :private_note, with: ->(value) { value.gsub(/\r\n?/, "\n").strip }
  validates :private_note, presence: true, length: { maximum: OfficialPayment::NOTE_MAX_LENGTH }
end
