PayPal::SDK::Core::Config.load("config/paypal.yml", Rails.env)
PayPal::SDK.logger = Rails.logger
