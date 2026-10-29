Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src :self
  policy.img_src :self, :data
  policy.script_src :self
  if Rails.env.development?
    policy.script_src :self, "http://localhost:3036"
    policy.connect_src :self, "http://localhost:3036", "ws://localhost:3036"
  end


  policy.style_src :self

  policy.object_src :none
  policy.base_uri :self
  policy.form_action :self
  policy.frame_ancestors :none
end
Rails.application.config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src style-src]
