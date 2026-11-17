class HorizonConnection < ApplicationRecord
  encrypts :authorization_code, :access_token
  validates :authorization_code, presence: true

  def access_token_for_request
    # The storage volume is shared across web processes and releases. A 409 can
    # occur if Horizon has already issued a token, so serialize exchanges.
    File.open(Rails.root.join("storage", "horizon-token-#{id}.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      reload
      return access_token if access_token.present? && access_token_expires_at.present? && access_token_expires_at > Time.current

      token = Horizon::Client.new.request_token(authorization_code: authorization_code)
      expires = Integer(token.fetch("token_expires"))
      raise Horizon::Client::ResponseError, "Horizon returned an invalid token expiry" if expires <= Time.current.to_i
      value = token.fetch("access_token").to_s
      raise Horizon::Client::ResponseError, "Horizon returned an invalid access token" if value.blank?
      organization = token["organization"]
      name = organization.first["name"] if organization.is_a?(Array) && organization.first.is_a?(Hash)
      update!(access_token: value, access_token_expires_at: Time.at(expires), organization_name: name.presence)
      value
    end
  rescue KeyError, ArgumentError, TypeError
    raise Horizon::Client::ResponseError, "Horizon returned an invalid token response"
  end
end
