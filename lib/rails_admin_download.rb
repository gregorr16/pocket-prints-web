require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

module RailsAdminDownload
end

module RailsAdmin
  module Config
    module Actions
      class Download < RailsAdmin::Config::Actions::Base
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
          'icon-download-alt' 
        end        

        register_instance_option :route_fragment do
          'download'
        end
        register_instance_option :authorization_key do
          :download
        end
        register_instance_option :member do
          true
        end
        
        register_instance_option :controller do 
          Proc.new do 
            if request.get?
             
            elsif request.put?
              #OrderMailer.downloaded(@object).deliver unless params[:download].blank?
              unless params[:download].blank?
                send_file @object.download!
              end
              
              # respond_to do |format|
              #   format.html { redirect_to_on_success }
              #   format.js { render :json => { :id => @object.id.to_s, :label => @model_config.with(:object => @object).object_label } }
              # end
            end
          end
        end
      end
    end
  end
end

