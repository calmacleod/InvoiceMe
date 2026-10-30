class GameOrder
  COLUMNS = {
    "external_id" => "games.external_id COLLATE NOCASE",
    "code" => "games.code COLLATE NOCASE",
    "date" => "games.date",
    "home_team" => "games.home_team COLLATE NOCASE",
    "away_team" => "games.away_team COLLATE NOCASE",
    "location" => "games.location COLLATE NOCASE",
    "official_count" => "json_array_length(games.officials)",
    "fees_cents" => "games.fees_cents"
  }.freeze

  def initialize(column, direction)
    @column = COLUMNS.key?(column) ? column : "date"
    @direction = %w[asc desc].include?(direction) ? direction : "desc"
  end

  def apply(scope)
    column = Arel.sql(COLUMNS.fetch(@column))
    scope.reorder(@direction == "asc" ? column.asc : column.desc, external_id: :asc, id: :asc)
  end

  def props = { column: @column, direction: @direction }
end
