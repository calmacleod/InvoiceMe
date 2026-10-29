key = Rails.application.key_generator.generate_key("invoice-me-tokens", 64).unpack1("H*")
Rails.application.config.active_record.encryption.primary_key = key[0, 32]
Rails.application.config.active_record.encryption.deterministic_key = key[32, 32]
Rails.application.config.active_record.encryption.key_derivation_salt = key[64, 32]
