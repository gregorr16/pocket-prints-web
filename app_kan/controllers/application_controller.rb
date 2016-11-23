class ApplicationController < ActionController::Base

  def token_required
    is_invalid_token = true

    if params[:token].present?
      @customer = Customer.where(token: params[:token]).first
      is_invalid_token = false if @customer.present?
    end

    if is_invalid_token
      @error = I18n.t('customer.null_or_invalid_token')
      render "api/v1/shared/error"
      return false
    else
      return true
    end
  end

  def is_alive
    render json: {ok: true}
  end

  def gift
    redirect_to "pocketprints://?code=#{params[:code]}&email=#{params[:email_address]}"
    return
  end

  protected

  def render_error
    render "api/v1/shared/error"
    return
  end

end
