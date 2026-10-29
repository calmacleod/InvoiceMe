class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]
  rate_limit to: 10, within: 5.minutes, only: :create
  def new; end
  def create
    password = ENV["ADMIN_PASSWORD"].presence || ("invoice-local" if Rails.env.development? || Rails.env.test?)
    if password && ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(params[:password].to_s), Digest::SHA256.hexdigest(password))
      reset_session
      session[:authenticated_at] = Time.current.to_i
      redirect_to root_path
    else
      flash.now[:alert] = "The password is incorrect"
      render :new, status: :unprocessable_entity
    end
  end
  def destroy
    reset_session
    redirect_to login_path
  end
end
