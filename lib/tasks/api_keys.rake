namespace :api_keys do
  desc "Issue an API key: EMAIL=... NAME=... WRITE=true bin/rails api_keys:issue"
  task issue: :environment do
    user = User.find_by!(email_address: ENV.fetch("EMAIL").strip.downcase)
    key, token = ApiKey.issue!(user: user, name: ENV.fetch("NAME"), write_access: ENV["WRITE"] == "true")
    puts "Key #{key.id} (save this token now; it cannot be recovered):"
    puts token
  end

  desc "Revoke an API key: ID=... bin/rails api_keys:revoke"
  task revoke: :environment do
    ApiKey.find(ENV.fetch("ID")).update!(revoked_at: Time.current)
    puts "Key revoked"
  end
end
