class Game < ApplicationRecord
  belongs_to :season
  has_many :invoice_games, dependent: :restrict_with_error
  has_many :invoices, through: :invoice_games
  validates :external_id, presence: true, uniqueness: { scope: :season_id }
  validates :date, presence: true
  validates :fees_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  def matchup = [away_team.presence, home_team.presence].compact.join(" at ").presence || "Game #{external_id}"
end
