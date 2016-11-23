module Api
  module V1
    class CustomersController < ApplicationController
      respond_to :json
      before_filter :token_required, only: [:update]

      def token
        # make new customer then return the token
        random_token = SecureRandom.urlsafe_base64(nil, false)
        @customer = Customer.new({token: random_token})

        @customer.update_attributes({ name: params[:name], email: params[:email], phone: params[:phone], 
            device_name: params[:device_name], os_version: params[:os_version], params: params.to_s })
      end

      def update
        [:name, :email, :phone, :device_name, :os_version].each do |e|
          @customer[e] = params[e]
        end

        @customer.infos ||= []
        @customer.infos << params.to_s

        @customer.save
      end

      def email_template
        render :layout => "email_template1"
      end

      def gift_email_template
        render :layout => "email_template_for_gift"
      end
    end
  end
end
