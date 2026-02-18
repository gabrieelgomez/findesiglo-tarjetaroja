# Agregar el campo identifier a los atributos permitidos de Spree::User
Rails.application.config.to_prepare do
  Spree::PermittedAttributes.user_attributes << :identifier
end 