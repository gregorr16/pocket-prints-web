class OrderMailer < ActionMailer::Base
  include ActionView::Helpers::NumberHelper

  BCC_EMAIL = "hello@pocketprints.com.au"
  ADMIN_EMAIL = "orders@pocketprints.com.au"

  layout 'email_template1', :only => [:shipped, :downloaded, :created, :gift_certificates_vouchers_order]

  default from: BCC_EMAIL

  ##
  # Get email to for each ENV
  # For testing, development: ENV = :test => email will go to test email
  # For live server, ENV = :live => email will go to real email
  ##
  def email_to(email)
    env = :live

    if env == :live
      email
    else
      email_test = 'vuongtieulong02@gmail.com'
    end
  end

  def potential_fraud_warning(order, paypal_total, app_total, server_total)
    @order = order
    @paypal_total = paypal_total
    @app_total = app_total
    @server_total = server_total
    to = ["team@appiphany.com.au", ADMIN_EMAIL]

    mail :to => email_to(to), :subject => "Potential Fraud Warning"
  end

  def shipped(order)
    @order = order
    to = @order.email

    mail :to => email_to(to), :subject => "Your Pocket Prints Order ##{order.order_code} has been Sent!"
  end

  def created(order)
    @order = order
    to = @order.email

    mail :to => email_to(to), :subject => "Confirmation of your Pocket Prints Order ##{order.order_code}"
  end

  #Not need as currently
  def downloaded(order)
    @order = order
    to = @order.email

    mail :to => email_to(to), :subject => "Your Pocket Prints Order ##{order.order_code} is being processed"
  end

  def gift_certificates_vouchers(order, voucher)
    @order = order
    @voucher = voucher

    gift_value_txt = "#{number_to_currency @voucher.purchase_price, strip_insignificant_zeros: true}"

    #attachments["gift_certificate.jpg"] = File.read(Rails.root.join('app', 'assets', 'static', 'gift_certificate.jpg'))
    mail( :to => email_to(@voucher.email_address), :subject => "You have received a Pocket Prints Gift Certificate from #{@order.first_name} with the value of #{gift_value_txt}") do |format|
    format.html { render layout: 'layouts/email_template_for_gift' }
    end

  end
  # notify to who ordered voucher
  def gift_certificates_vouchers_order(order, voucher)
    @order = order
    @voucher = voucher

    gift_value_txt = "#{number_to_currency @voucher.purchase_price, strip_insignificant_zeros: true}"

    #attachments["gift_certificate.jpg"] = File.read(Rails.root.join('app', 'assets', 'static', 'gift_certificate.jpg'))
    mail :to => email_to(@order.email), :subject => "Confirmation of your Pocket Prints Order ##{order.order_code}"
  end

  ##
  # Notify when order is created
  ##
  def notify_order(order)
    @order = order
    to = ADMIN_EMAIL

    mail :to => email_to(to), :subject => "Pocket Prints Order ##{order.order_code}"
  end

  ##
  # Notify when get an error when creating order
  ##
  def notify_error(order, error, params)
    @order = order
    @error = error
    @params = params
    to = ["vuongtieulong02@gmail.com", "adrian@appiphany.com.au"]

    mail :to => email_to(to), :subject => "[Pocket Prints] Error when creating Order"
  end

  ##
  # Notify when get an error when creating order
  ##
  def notify_error_retry_ftp_upload_failed(order, error)
    @order = order
    @error = error
    to = ["vuongtieulong02@gmail.com"]

    mail :to => email_to(to), :subject => "[Pocket Prints] Error when retry upload Order to FTP"
  end
end
