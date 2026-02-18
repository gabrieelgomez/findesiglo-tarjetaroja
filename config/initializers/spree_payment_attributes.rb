# Permitir atributos personalizados en payments para checkout
Spree::PermittedAttributes.payment_attributes << :referencia
Spree::PermittedAttributes.payment_attributes << :receipt_image 