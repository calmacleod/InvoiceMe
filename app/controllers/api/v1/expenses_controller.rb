module Api
  module V1
    class ExpensesController < BaseController
      include ExpenseParameters
      rescue_from ActiveRecord::StaleObjectError, with: -> { render_error("This expense changed. Reload it and try again.", :conflict) }

      def index
        register = ExpenseRegister.new(season)
        scope = register.filtered(**expense_filters)
        page = WorkspacePage.new(scope, params[:page], params[:per_page])
        render json: {
          data: page.records.includes(:line_items).map(&:details),
          pagination: page.props,
          summary: register.summary,
          categories: register.categories,
          preset_categories: Expense::PRESET_CATEGORIES
        }
      end

      def show
        render json: expense.details
      end

      def create
        record = season.expenses.build
        record.save_details!(expense_params.except(:lock_version))
        render json: record.details, status: :created
      end

      def update
        expense.save_details!(expense_params)
        render json: expense.details
      end

      def destroy
        expense.destroy!
        head :no_content
      end

      private

      def season = @season ||= Season.find(params.require(:season_id))
      def expense = @expense ||= Expense.find(params[:id])
    end
  end
end
