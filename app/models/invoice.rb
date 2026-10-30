class Invoice < ApplicationRecord
  belongs_to :season
  has_many :line_items, -> { order(:position, :id) }, dependent: :destroy
  has_many :invoice_games, dependent: :destroy
  has_many :games, through: :invoice_games
  has_many :payments, dependent: :restrict_with_error
  has_many :invoice_drafts, dependent: :destroy
  has_many :invoice_exports, dependent: :destroy
  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: ->(a) { a["description"].blank? && a["rate"].blank? }
  validates :number, :recipient, :description, :issued_on, presence: true
  validates :number, uniqueness: { scope: :season_id }, format: { with: /\A[\p{L}\p{N}_. -]+\z/, message: "may contain letters, numbers, spaces, underscores, periods, and hyphens" }, length: { maximum: 120 }
  validate :has_items
  validate :same_season_games
  validate :valid_contacts
  validate :immutable_when_finalized, on: :update
  before_validation :normalize_contacts
  def contacts = super || InvoiceContacts.from_legacy(contact)
  def contact_names = contacts.filter_map { |contact| contact["name"].presence }.join(", ")
  def contact_email = contacts.filter_map { |contact| contact["email"].presence }.first.to_s
  def attention = contact_names.presence || recipient
  def total_cents = line_items.reject(&:marked_for_destruction?).sum(&:total_cents)
  def received_cents = payments.loaded? ? payments.select(&:persisted?).sum(&:amount_cents) : payments.sum(:amount_cents)
  def owed_cents = total_cents - received_cents
  def issuer = issuer_snapshot || season.issuer
  def destination = destination_snapshot || season.destination
  def exporting? = persisted? && invoice_exports.active.exists?
  def editing_blocked? = finalized_at.present? || exporting?
  def ensure_previewed_for_export!
    if !finalized_at && invoice_drafts.where.not(data: {}).exists?
      raise GoogleApi::Error, "This invoice has workbench edits. Resume the draft and use Save & preview before publishing."
    end
  end
  def status
    return "Draft" unless finalized_at
    return "Needs sync" unless published_at
    return "Paid" if owed_cents <= 0
    return "Part paid" if received_cents > 0
    "Outstanding"
  end
  def finalize!
    with_lock do
      return if finalized_at
      update!(issuer_snapshot: season.issuer.deep_dup, destination_snapshot: season.destination.deep_dup, finalized_at: Time.current)
    end
  end
  private
  def normalize_contacts
    return unless self[:contacts] && InvoiceContacts.valid_format?(self[:contacts])

    self.contacts = self[:contacts].map do |contact|
      { "name" => contact["name"].strip, "email" => contact["email"].strip.downcase }
    end.reject { |contact| contact.values.all?(&:blank?) }
  end
  def valid_contacts
    return if self[:contacts].nil?

    unless InvoiceContacts.valid_format?(contacts)
      errors.add(:contacts, "must contain names and emails")
      return
    end
    contacts.each_with_index do |contact, index|
      errors.add(:contacts, "contact #{index + 1} needs a valid email") if contact["email"].present? && !URI::MailTo::EMAIL_REGEXP.match?(contact["email"])
      errors.add(:contacts, "contact #{index + 1} name must not include an email") if contact["name"].include?("@")
    end
  end
  def has_items
    errors.add(:base, "Add at least one line item") if line_items.reject(&:marked_for_destruction?).empty?
  end
  def same_season_games
    errors.add(:games, "must belong to the invoice year") if games.any? { |g| g.season_id != season_id }
  end
  def immutable_when_finalized
    return unless finalized_at_in_database
    allowed = %w[private_notes published_at google_doc_id google_pdf_id ledger_row publish_error updated_at]
    errors.add(:base, "Finalized invoices cannot be edited; create a new invoice for a correction") if (changed - allowed).any? || line_items.any?(&:changed_for_autosave?)
  end
end
