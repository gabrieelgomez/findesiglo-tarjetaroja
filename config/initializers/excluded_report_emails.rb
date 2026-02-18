# Emails de usuarios cuyas órdenes se excluyen de reportes de ventas en admin
# (ej. traspasos entre tiendas que no deben contarse como ventas)
Rails.application.config.x.excluded_report_emails = [
  'traspaso@tarjetaroja.com'
].freeze
