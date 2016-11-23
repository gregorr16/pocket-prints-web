node :uid do |id|
  @photo.try(:id).to_s
end
