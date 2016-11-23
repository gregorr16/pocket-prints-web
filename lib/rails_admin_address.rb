require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

module RailsAdminAddress
end

module RailsAdmin
  module Config
    module Actions
      class Address < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
      
        register_instance_option :http_methods do
          [:get]
        end
        register_instance_option :visible? do        
          authorized? && bindings[:object].is_a?(Order) rescue false 
        end
        
        register_instance_option :object_level do
          true
        end
        
        # http://getbootstrap.com/2.3.2/base-css.html#icons
        register_instance_option :link_icon do
          'icon-home' 
        end        

        register_instance_option :route_fragment do
          'address'
        end
        register_instance_option :authorization_key do
          :address
        end
        register_instance_option :member do
          true
        end
        
        register_instance_option :controller do 
          Proc.new do 
            if request.get?
              
            end
          end
        end
      end
    end
  end
end

