Season.find_or_create_by!(year: 2026) do |season|
  season.issuer = Season::DEFAULT_ISSUER
  season.sheet_name = "2026 invoices"
  season.drive_folder_id = "1PXMPpSVa7AmmVXGW6jX05QsUkEe7AiZr"
  season.spreadsheet_id = "1uzqihjp3MLLPu9AkJpHfgN8pvdA70s-7gIxnGZ6k5f8"
end

# Provision an initial account explicitly; never reset an existing user's password.
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  User.find_or_create_by!(email_address: ENV.fetch("ADMIN_EMAIL").strip.downcase) do |user|
    user.password = ENV.fetch("ADMIN_PASSWORD")
    user.password_confirmation = ENV.fetch("ADMIN_PASSWORD")
  end
end
