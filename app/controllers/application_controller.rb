class ApplicationController < ActionController::Base
  before_action :require_login
  helper_method :current_season
  rescue_from GoogleApi::Error, with: ->(e) { redirect_back fallback_location: root_path, alert: e.message }
  private
  def require_login
    redirect_to login_path unless session[:authenticated_at] && session[:authenticated_at] > 12.hours.ago.to_i
  end
  def current_season
    @current_season ||= Season.find_by(id: params[:season_id].presence || session[:season_id]) || Season.order(year: :desc).first
  end
  def need_season
    redirect_to new_season_path, alert: "Set up your first invoice year" unless current_season
  end
end
