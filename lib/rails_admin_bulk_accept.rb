module RailsAdmin
  module Config
    module Actions
      class BulkAccept < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:post, :delete]
        end

        register_instance_option :controller do
          Proc.new do
            if request.post? 

              @objects = list_entries(@model_config, :accept)

              render @action.template_name

            elsif request.delete? # BULK DESTROY
              @objects = list_entries(@model_config, :accept)
              @objects.map(&:accept!)             
              flash[:success] = t("admin.flash.successful", :name => pluralize(@objects.count, @model_config.label), :action => t("admin.actions.accept.done")) unless @objects.empty?
             
              redirect_to back_or_index

            end
          end
        end

        register_instance_option :authorization_key do
          :accept
        end

        register_instance_option :bulkable? do
          true
        end
      end
    end
  end
end