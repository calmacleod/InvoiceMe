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

  def games_locked?
    invoices.where.not(destination_snapshot: nil).or(invoices.where.not(finalized_at: nil)).exists? ||
      InvoiceExport.active.where(invoice_id: invoices.select(:id)).exists?
  end

  def matching_invoices
    selection = invoice_group_games.select(:game_id)
    matches = InvoiceGame.where(game_id: selection).group(:invoice_id)
      .having("COUNT(*) = ?", invoice_group_games.count).select(:invoice_id)
    other_games = InvoiceGame.where.not(game_id: selection).select(:invoice_id)
    season.invoices.where(invoice_group_id: nil, id: matches).where.not(id: other_games)
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
  def reject_selection!(message)
    errors.add(:games, message)
    raise ActiveRecord::RecordInvalid.new(self)
  end
end
