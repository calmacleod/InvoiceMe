class ApplicationController < ActionController::Base
  include Authentication
  include WorkspaceProps

  inertia_share do
    signed_in = authenticated?
    {
      auth: signed_in ? { email: Current.user.email_address } : nil,
      seasons: signed_in ? Season.order(year: :desc).as_json(only: %i[id year]) : [],
      current_season: signed_in && current_season ? { id: current_season.id, year: current_season.year } : nil,
      flash: flash.to_hash,
      today: Date.current.iso8601,
      section: controller_name,
      logo_url: helpers.asset_path("eotfoa-logo.jpg")
    }
  end
  helper_method :current_season
  rescue_from GoogleApi::Error, with: ->(e) { redirect_back fallback_location: root_path, alert: e.message }
  private
  def current_season
    @current_season ||= Season.find_by(id: params[:season_id].presence || session[:season_id]) || Season.order(year: :desc).first
  end
  def need_season
    redirect_to new_season_path, alert: "Set up your first invoice year" unless current_season
  end
end
