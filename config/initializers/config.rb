CONFIG = HashWithIndifferentAccess.new YAML.load(File.read(Rails.root.join('config/config.yml')))[Rails.env]

ERROR_CODES = {
  normal: 1,
  user_is_expired: 2,
  not_found: 3,
  stripe_paypal_error: 4,
  stripe_paypal_amount_wrong: 5
}