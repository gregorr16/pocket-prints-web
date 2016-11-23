Airbrake.configure do |config|
  config.api_key     = '68d67a4f960d2331dea050b4e580b0a3'
  config.host        = 'errbit.appiphany.com.au'
  config.port        = 80
  config.secure      = config.port == 443
end