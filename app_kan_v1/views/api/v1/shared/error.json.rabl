node(:error) { @error }

if defined?(@error_code) && @error_code
  node(:error_code) { @error_code }
else
  node(:error_code) { ERROR_CODES[:normal] }
end

if defined?(@used_expired_promotions) && !@used_expired_promotions.blank?
	node(:used_expired_promotions) { @used_expired_promotions }
end