if Rails.env.to_s == "production"
	Rails.configuration.stripe = {
	  :secret_key      => 'sk_live_1FzoaM0UIr3mz2vGAYtt07QE'
	}
else
	Rails.configuration.stripe = {
	  :secret_key      => 'sk_test_3zdwdRDBG3vnAHl14w2zeqvs'
	}
end

Stripe.api_key = Rails.configuration.stripe[:secret_key]