class OrderDetail < ApplicationRecord
  belongs_to :spree_order, class_name: 'Spree::Order', foreign_key: 'order_id'

  enum :operator, {
    miguel_gomez: 2,
    gabriel_gomez: 3,
    neptali_bracho: 4,
    diego_santos: 6,
    todos: 99
  }

  enum :type_service, {
    starter_basic: 0,
    premium_express: 1
  }

  validates :description, presence: true
  validates :operator, presence: true
  validates :type_service, presence: true

  # Atributos permitidos para búsquedas con Ransack
  def self.ransackable_attributes(auth_object = nil)
    ["description", "description_short", "operator", "type_service", "delivery_time", "spree_order_number", "spree_order_id", "id", "id_value", "created_at", "updated_at"]
  end

  # Asociaciones permitidas para búsquedas con Ransack
  def self.ransackable_associations(auth_object = nil)
    ["spree_order"]
  end
end
