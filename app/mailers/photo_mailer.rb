class PhotoMailer < ActionMailer::Base
  default from: "hello@pocketprints.com.au"

  BCC_EMAIL = "hello@pocketprints.com.au"
  ADMIN_EMAIL = "orders@pocketprints.com.au"

  ##
  # Get email to for each ENV
  # For testing, development: ENV = :test => email will go to test email
  # For live server, ENV = :live => email will go to real email
  ##
  def email_to(email)
    env = :live

    if env == :live1
      email
    else
      email_test = 'lienptb@elarion.com'
    end
  end

  ##
  # Notify when get an error when creating order
  ##
  def notify_error(photo, error, params)
  	@photo = photo
    @error = error
    @params = params
    to = ["lienptb@elarion.com", "adrian@appiphany.com.au"]

    mail :to => email_to(to), :subject => "[Pocket Prints] Error when uploading Photo"
  end
end
