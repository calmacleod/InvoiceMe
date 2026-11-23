class InvoiceGroup < ApplicationRecord
  belongs_to :season
  has_many :invoice_group_games, dependent: :destroy
  has_many :games, through: :invoice_group_games
  has_many :invoices, dependent: :restrict_with_error
  has_many :invoice_drafts, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, length: { maximum: 120 }

  def self.start!(season:, game_ids:)
    group = season.invoice_groups.new
    games = group.resolve_games(game_ids)
    first, last = games.map(&:date).minmax
    group.name = first == last ? "Games on #{first.to_fs(:long)}" : "Games from #{first.to_fs(:long)} to #{last.to_fs(:long)}"
    group.games = games
    group.save!
    group
  end

  def self.for_invoice!(invoice, draft_id: nil)
    invoice.with_lock do
      next invoice.invoice_group if invoice.invoice_group_id

      draft = invoice.invoice_drafts.to_a.find { |candidate| candidate.id == draft_id }
      original_ids = invoice.game_ids.sort
      ids = draft&.data&.fetch("game_ids", nil)&.map(&:to_i)&.sort || original_ids
      if ids != original_ids && (invoice.ever_finalized? || invoice.editing_blocked?)
        invoice.errors.add(:games, "must match the saved games on invoices that have been finalized or are exporting")
        raise ActiveRecord::RecordInvalid.new(invoice)
      end
      invoice.verify_group_workbenches!([ original_ids, ids ])

      start!(season: invoice.season, game_ids: ids).tap { |group| invoice.attach_to_group!(group) }
    end
  end

  def self.for_workbench!(draft)
    return for_invoice!(draft.invoice, draft_id: draft.id) if draft.invoice_id

    draft.with_lock do
      raise ActiveRecord::StaleObjectError.new(draft, "group") if draft.invoice_id

      draft.invoice_group || start!(season: draft.season, game_ids: draft.data["game_ids"]).tap do |group|
        draft.update!(invoice_group: group, data: draft.data.except("game_ids"))
      end
    end
  end

  def attachment_review(invoice)
    original_ids, shared_ids = invoice.game_ids.sort, game_ids.sort
    {
      shared_game_count: shared_ids.size,
      games_added: shared_ids - original_ids,
      games_removed: original_ids - shared_ids,
      blocked_reason: attachment_blocker(invoice, original_ids, shared_ids),
      token: attachment_verifier.generate([ id, invoice.id, original_ids, shared_ids ], expires_in: 30.minutes)
    }
  end

  def attach_invoice!(invoice, review_token: nil)
    with_lock do
      invoice.with_lock do
        next if invoice.invoice_group_id == id

        original_ids, shared_ids = invoice.game_ids.sort, game_ids.sort
        blocker = attachment_blocker(invoice, original_ids, shared_ids)
        reject_attachment!(invoice, blocker) if blocker
        if (review_token.present? || original_ids != shared_ids) &&
            attachment_verifier.verified(review_token.to_s) != [ id, invoice.id, original_ids, shared_ids ]
          reject_attachment!(invoice, "Review the current game changes before adding this invoice")
        end
        invoice.verify_group_workbenches!([ original_ids, shared_ids ])
        invoice.attach_to_group!(self)
      end
    end
  end

  def games_locked?
    invoices.where.not(destination_snapshot: nil).or(invoices.where.not(finalized_at: nil)).exists? ||
      InvoiceExport.active.where(invoice_id: invoices.select(:id)).exists?
  end

  # Keep the existing invoice game references in step with the group so game
  # searches, invoice links and downstream callers see the same associations.
  def update_selection!(name:, game_ids:, revision:)
    with_lock do
      raise ActiveRecord::StaleObjectError.new(self, "update") unless lock_version.to_s == revision.to_s

      self.name = name
      if game_ids
        selected = resolve_games(game_ids)
        if selected.map(&:id).sort != self.game_ids.sort
          reject_selection!("are locked once an invoice has been finalized or is exporting") if games_locked?
          self.games = selected
          self.updated_at = Time.current
          invoices.each do |invoice|
            invoice.invoice_group = self
            invoice.update!(game_ids: self.game_ids)
          end
        end
      end
      save!
    end
  end

  def resolve_games(ids)
    ids = Array(ids).map(&:to_s).uniq
    reject_selection!("must include at least one game") if ids.empty?
    reject_selection!("must belong to this year") unless ids.all? { |id| id.match?(/\A[1-9]\d*\z/) }
    games = season.games.where(id: ids).to_a
    reject_selection!("must belong to this year") unless games.size == ids.size
    games
  end

  private

  def attachment_blocker(invoice, original_ids, shared_ids)
    return "This invoice already belongs to an invoice group." if invoice.invoice_group_id
    return if original_ids == shared_ids
    return "Wait for the current export to finish before updating this invoice’s linked games." if invoice.exporting?
    "This invoice has been finalized. Its existing game links must match the group’s games." if invoice.locked_game_history? && original_ids.any?
  end

  def attachment_verifier = Rails.application.message_verifier(:invoice_group_attachment)

  def reject_attachment!(invoice, message)
    invoice.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid.new(invoice)
  end

  def reject_selection!(message)
    errors.add(:games, message)
    raise ActiveRecord::RecordInvalid.new(self)
  end
end
