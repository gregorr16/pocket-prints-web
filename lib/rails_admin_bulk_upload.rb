require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

module RailsAdminBulkUpload
end

module RailsAdmin
  module Config
    module Actions
      class BulkUpload < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
              
        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:post, :get]
        end
        
        register_instance_option :visible? do 
         authorized? && (bindings[:abstract_model].to_s ==  'Photo')
        end
        
        register_instance_option :link_icon do
          'icon-upload' 
        end
        
        register_instance_option :controller do
          Proc.new do
            if request.get?
              @object = Photo.new
              render @action.template_name
            elsif request.post?              
              @object = Photo.new(params[:photo])
              @object.image = nil
              @object.user = current_user
              
              if @object.valid?
                notice = t("admin.flash.successful", :name => @model_config.label, :action => t("admin.actions.#{@action.key}.done"))
                #Copy the  zipfile to safety places
                new_filename = File.join(Rails.root, 'log', "#{params[:photo][:image].original_filename}-#{Time.now.to_i}") if params[:photo][:image]
                FileUtils.cp(params[:photo][:image].try(:path), new_filename) if params[:photo][:image]
                Photo.delay.bulk_create(new_filename, current_user.id, site_id: @object.site_id, project_id: @object.project_id, direction: @object.direction)
                redirect_to back_or_index, :flash => { :success => notice }
              else               
                handle_save_error :bulk_upload
              end
             end
          end
        end

        
        
      end
    end
  end
end