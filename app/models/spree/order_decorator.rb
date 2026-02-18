module Spree
  module OrderDecorator
    def self.prepended(base)
      base.has_one :order_detail, class_name: 'OrderDetail', foreign_key: 'order_id'
      base.attribute :completed, :boolean, default: false
      base.has_one_attached :invoice_image, service: Spree.public_storage_service_name
      base.has_one_attached :tracking_image, service: Spree.public_storage_service_name
    end
  end
end

Spree::Order.prepend(Spree::OrderDecorator) 