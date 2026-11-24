class ExpenseRegister
  def initialize(season)
    @season = season
  end

  def filtered(query: nil, category: nil, status: nil)
    scope = @season.expenses
    if query.present?
      match = "%#{Expense.sanitize_sql_like(query.strip, "!")}%"
      scope = scope.where("payee LIKE :match ESCAPE '!' OR description LIKE :match ESCAPE '!' OR reference LIKE :match ESCAPE '!' OR cheque_number LIKE :match ESCAPE '!'", match: match)
    end
    if category.present?
      item_ids = ExpenseLineItem.where("LOWER(category) = ?", category.downcase).select(:expense_id)
      scope = scope.where("LOWER(category) = ?", category.downcase).or(scope.where(id: item_ids))
    end
    scope = scope.where(paid: status == "paid") if %w[paid unpaid].include?(status)
    scope.order(incurred_on: :desc, id: :desc)
  end

  def expenses
    @expenses ||= @season.expenses.order(incurred_on: :desc, id: :desc).includes(:line_items).to_a
  end

  def categories
    used = expenses.flat_map { |expense| [ expense.category, *expense.line_items.map(&:category) ] }.compact
    (used + Expense::DEFAULT_CATEGORIES).uniq(&:downcase).sort_by(&:downcase)
  end

  def summary
    totals = { total_cents: 0, paid_cents: 0, unpaid_cents: 0, count: expenses.size }
    categories = {}
    expenses.each do |expense|
      payment_key = expense.paid? ? :paid_cents : :unpaid_cents
      totals[:total_cents] += expense.total_cents
      totals[payment_key] += expense.total_cents
      expense.allocations.each do |category, amount|
        entry = categories[category.downcase] ||= { category: category, total_cents: 0, paid_cents: 0, unpaid_cents: 0 }
        entry[:total_cents] += amount
        entry[payment_key] += amount
      end
    end
    totals.merge(by_category: categories.sort.map(&:last))
  end
end
