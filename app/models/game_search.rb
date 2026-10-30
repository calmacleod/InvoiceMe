class GameSearch
  FIELDS = %w[q home_team away_team code location official date_from date_to link_status].freeze
  attr_reader :filters, :errors

  def initialize(scope, values, user:)
    @scope, @user = scope, user
    @filters = FIELDS.index_with { |key| values[key].to_s.strip.first(200) }
    @filters["link_status"] = "" unless %w[linked unlinked invoiced workbench].include?(@filters["link_status"])
    @errors = []
  end

  def results
    scope = @scope
    if filters["q"].present?
      value = contains(filters["q"])
      scope = scope.where(%q(games.external_id LIKE :q ESCAPE '\' OR games.code LIKE :q ESCAPE '\' OR games.home_team LIKE :q ESCAPE '\' OR games.away_team LIKE :q ESCAPE '\' OR games.location LIKE :q ESCAPE '\'), q: value)
    end
    %w[home_team away_team code location].each do |field|
      scope = scope.where("games.#{field} LIKE ? ESCAPE '\\'", contains(filters[field])) if filters[field].present?
    end
    if filters["official"].present?
      scope = scope.where(%q{EXISTS (SELECT 1 FROM json_each(games.officials) AS official WHERE json_extract(official.value, '$.name') LIKE ? ESCAPE '\')}, contains(filters["official"]))
    end
    from, to = date("date_from"), date("date_to")
    errors << "The start date must be on or before the end date." if from && to && from > to
    return scope.none if errors.any?
    scope = scope.where(date: from..) if from
    scope = scope.where(date: ..to) if to
    invoice_ids = InvoiceGame.select(:game_id)
    draft_ids = self.class.workbench_games(@user).select(Arel.sql("CAST(selected_games.value AS INTEGER)"))
    case filters["link_status"]
    when "invoiced" then scope.where(id: invoice_ids)
    when "workbench" then scope.where(id: draft_ids)
    when "linked" then scope.where(id: invoice_ids).or(scope.where(id: draft_ids))
    when "unlinked" then scope.where.not(id: invoice_ids).where.not(id: draft_ids)
    else scope
    end
  end

  def self.workbench_games(user)
    InvoiceDraft.where(user: user).open_work.reorder(nil)
      .joins(<<~SQL.squish)
        JOIN json_each(CASE
          WHEN json_type(invoice_drafts.data, '$.game_ids') IS NOT NULL
            THEN json_extract(invoice_drafts.data, '$.game_ids')
          ELSE (SELECT json_group_array(game_id) FROM invoice_games WHERE invoice_id = invoice_drafts.invoice_id)
        END) AS selected_games
      SQL
  end

  private
  def contains(value) = "%#{Game.sanitize_sql_like(value)}%"
  def date(field)
    return if filters[field].blank?
    raise Date::Error unless filters[field].match?(/\A\d{4}-\d{2}-\d{2}\z/)
    Date.iso8601(filters[field])
  rescue Date::Error
    errors << "Choose a valid #{field == 'date_from' ? 'start' : 'end'} date."
    nil
  end
end
