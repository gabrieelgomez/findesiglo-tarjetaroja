# Agregar el campo identifier y agency a los atributos permitidos de Spree::Address
Rails.application.config.to_prepare do
  Spree::PermittedAttributes.address_attributes << :identifier
  Spree::PermittedAttributes.address_attributes << :agency
end 