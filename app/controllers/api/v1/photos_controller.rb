module Api
  module V1
    class PhotosController < ApplicationController
      respond_to :json
      before_filter :token_required

      def create
        @photo = @customer.photos.new

        @photo.params = params.to_s

        if params[:image].blank?
          @error = t("photo.missing_image")
          render "api/v1/photos/create"

          error_notify(Exception.new(@error))
          return
        end
        
        if params[:image].is_a?(String)
          begin
            @photo.image_from_url(params[:image])
          rescue Exception => e
            @error = t("photo.invalid_url")
            render "api/v1/photos/create"

            error_notify(Exception.new("#{@error} : #{e.message}"))
            return
          end
        else
          @photo.image = params[:image]
        end

        @photo.save

        unless @photo.valid?
          # if @photo.errors.has_key?(:image_fingerprint)
          #   @photo = @customer.photos.where(image_fingerprint: @photo.image_fingerprint).first

          #   render "api/v1/photos/create"
          #   return
          # end
          if @photo.errors.has_key?(:image)
            @photo.url = upload_file_to_s3
          end

          @error = @photo.errors.full_messages

          error_notify(Exception.new(@error.join(", ")))

          render "api/v1/photos/create"
          return
        end
      end

      private

      def error_notify(exception)
        Airbrake.notify_or_ignore(exception) if defined?(Airbrake) && Rails.env.production?
        
        @photo.error = exception.message
        @photo.params = params.to_s
        @photo.success = false

        @photo.save(validate: false)
        Photo.delay.retry(@photo)
        
        PhotoMailer.delay.notify_error(@photo, @photo.error.to_s, params.to_s)
      end

      ##
      # After get zip file from Box, upload this file to S3
      ##
      def upload_file_to_s3
        return if params[:image].is_a?(String)

        begin
          url = ''

          s3 = AWS::S3.new(access_key_id: CONFIG[:amazon_access_key],
              secret_access_key: CONFIG[:amazon_secret])

          current_bucket = s3.buckets[CONFIG[:bucket]]

          obj = current_bucket.objects["#{@customer.token}/photos/#{Time.now.utc.to_i}-#{params[:image].original_filename}"]

          obj.write(params[:image].tempfile.read, :acl => :public_read)

          url = obj.public_url(:secure => true).to_s

          url
        rescue Exception => e
          Airbrake.notify_or_ignore(e) if defined?(Airbrake) && Rails.env.production?
          ""
        end
      end
    end
  end
end
