class Game < ApplicationRecord
  # Keep large imported JSON out of list queries. Details are fetched on demand.
  scope :summaries, -> {
    select(*column_names.excluding("officials", "source").map { |name| arel_table[name] })
      .select(Arel.sql("json_array_length(officials) AS summary_official_count"))
      .select(Arel.sql(%q{json_extract(source, '$[0]."Paid By Team"') AS paid_by_team}))
  }
  scope :matching, ->(query) {
    where("code LIKE :q OR external_id LIKE :q OR home_team LIKE :q OR away_team LIKE :q", q: "%#{sanitize_sql_like(query.to_s)}%") if query.present?
  }
  belongs_to :season
  has_many :invoice_games, dependent: :restrict_with_error
  has_many :invoices, through: :invoice_games
  validates :external_id, presence: true, uniqueness: { scope: :season_id }
  validates :date, presence: true
  validates :fees_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  def matchup = [ away_team.presence, home_team.presence ].compact.join(" at ").presence || "Game #{external_id}"
end
