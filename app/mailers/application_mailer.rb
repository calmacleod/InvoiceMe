class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "treasurer@eotfoa.ca")
  layout "mailer"
end
