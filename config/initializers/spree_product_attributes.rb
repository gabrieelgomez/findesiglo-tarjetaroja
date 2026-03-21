# Agregar campos personalizados a los atributos permitidos de Spree::Product.
# Usar to_prepare: en desarrollo, recargas pueden reinicializar PermittedAttributes
# y los << del boot quedarían sin efecto si solo están fuera de to_prepare.
Rails.application.config.to_prepare do
  attrs = Spree::PermittedAttributes.product_attributes
  attrs << :price_bcv unless attrs.include?(:price_bcv)
  attrs << :json_stock_url unless attrs.include?(:json_stock_url)
  attrs << :youtube_video_url unless attrs.include?(:youtube_video_url)
end
