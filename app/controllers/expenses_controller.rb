class ExpensesController < ApplicationController
  include ExpenseParameters

  before_action :need_season, only: %i[index new create sync]
  rescue_from ActiveRecord::StaleObjectError, with: :stale_expense

  def index
    register = ExpenseRegister.new(expense_season)
    filters = expense_filters
    render inertia: "expenses/Index", props: {
      expenses: -> { expense_page(register, filters).records.includes(:line_items).map(&:details) },
      pagination: -> { expense_page(register, filters).props },
      summary: -> { register.summary },
      categories: -> { register.categories },
      filters: filters,
      sync: -> { ExpenseSheetSync.for_season(expense_season) }
    }
  end

  def new
    default_date = Date.current if expense_season.year == Date.current.year
    render_form(expense_season.expenses.build(incurred_on: default_date))
  end

  def create
    expense = expense_season.expenses.build
    expense.save_details!(expense_params.except(:lock_version))
    redirect_to expenses_path(season_id: expense.season_id), notice: "Expense added"
  rescue ActiveRecord::RecordInvalid, ArgumentError => error
    redirect_to new_expense_path(season_id: expense_season.id), inertia: { errors: expense_errors(error) }
  end

  def edit
    render_form(expense)
  end

  def update
    expense.save_details!(expense_params)
    redirect_to expenses_path(season_id: expense.season_id), notice: "Expense saved"
  rescue ActiveRecord::RecordInvalid, ArgumentError => error
    redirect_to edit_expense_path(expense), inertia: { errors: expense_errors(error) }
  end

  def destroy
    expense.destroy!
    redirect_to expenses_path(season_id: expense.season_id), notice: "Expense deleted"
  end

  def sync
    ExpenseSheetSync.enqueue_for(expense_season)
    redirect_to expenses_path(season_id: expense_season.id), notice: "Expense sync queued"
  rescue GoogleApi::Error => error
    redirect_to expenses_path(season_id: expense_season.id), alert: error.message
  end

  private

  def expense_season
    @expense_season ||= params[:season_id].present? ? Season.find(params[:season_id]) : current_season
  end

  def expense = @expense ||= Expense.find(params[:id])

  def expense_page(register, filters)
    @expense_page ||= WorkspacePage.new(register.filtered(**filters), params[:page], params[:per_page])
  end

  def render_form(record)
    season = record.season
    render inertia: "expenses/Edit", props: {
      expense: record.details,
      season: { id: season.id, year: season.year },
      categories: ExpenseRegister.new(season).categories
    }
  end

  def stale_expense
    redirect_to edit_expense_path(expense), alert: "This expense changed. Reload the page before applying your edits again."
  end

  def expense_errors(error)
    error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors : { base: error.message }
  end
end
