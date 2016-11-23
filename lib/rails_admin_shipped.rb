require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

module RailsAdminShipped
end

module RailsAdmin
  module Config
    module Actions
      class Shipped < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
      
        register_instance_option :http_methods do
          [:put,:get]
        end
        register_instance_option :visible? do        
          authorized? && bindings[:object].is_a?(Order) rescue false 
        end
        
        register_instance_option :object_level do
          true
        end
        
        # http://twitter.github.com/bootstrap/base-css.html#icons
        register_instance_option :link_icon do
          'icon-thumbs-up' 
        end        

        register_instance_option :route_fragment do
          'shipped'
        end
        register_instance_option :authorization_key do
          :shipped
        end
        register_instance_option :member do
          true
        end
        
        register_instance_option :controller do 
          Proc.new do 
            if request.get?
              @object.shipped!
              
              respond_to do |format|
                format.html { redirect_to_on_success }
                format.js { render :json => { :id => @object.id.to_s, :label => @model_config.with(:object => @object).object_label } }
              end
            elsif request.put?
              @object.shipped! unless params[:shipped].blank?
              
              respond_to do |format|
                format.html { redirect_to_on_success }
                format.js { render :json => { :id => @object.id.to_s, :label => @model_config.with(:object => @object).object_label } }
              end
            end
          end
        end
      end
    end
  end
end

