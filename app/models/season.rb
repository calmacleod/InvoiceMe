class Season < ApplicationRecord
  DEFAULT_ISSUER = {
    "name" => "Eastern Ontario Tackle Football Officials’ Association",
    "payable_to" => "EASTERN ONTARIO TACKLE FOOTBALL OFFICIALS ASSOCIATION",
    "treasurer" => "Callum MacLeod", "email" => "treasurer@eotfoa.ca",
    "address" => "70 Laurel Street Unit 2\nOTTAWA, ON\nK1Y 3E2",
    "payment_instructions" => "Payment can be made either by check or e-transfer."
  }.freeze
  has_many :invoices, dependent: :restrict_with_error
  has_many :games, dependent: :restrict_with_error
  validates :year, uniqueness: true, numericality: { only_integer: true, in: 2000..2200 }
  validates :sheet_name, presence: true
  validates :ledger_start_row, numericality: { only_integer: true, greater_than_or_equal_to: 2, less_than: 100_000 }
  validate :valid_issuer
  before_validation do
    %w[drive_folder_id pdf_folder_id spreadsheet_id].each do |field|
      value = public_send(field).to_s.strip
      public_send("#{field}=", value[%r{/(?:d|folders)/([\w-]+)}, 1] || value)
      errors.add(field, "must be a Google ID or URL") if value.present? && !public_send(field).match?(/\A[\w-]+\z/)
    end
  end
  def export_ready? = drive_folder_id.present? && spreadsheet_id.present?
  def destination = attributes.slice("drive_folder_id", "pdf_folder_id", "spreadsheet_id", "sheet_name", "ledger_start_row")
  private
  def valid_issuer
    errors.add(:issuer, "needs an organization name, treasurer, email, and mailing address") unless %w[name treasurer email address].all? { |k| issuer[k].present? }
  end
end
