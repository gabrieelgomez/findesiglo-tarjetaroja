class Expense < ApplicationRecord
  belongs_to :spree_payment_method, class_name: 'Spree::PaymentMethod'
  belongs_to :spree_admin_user, class_name: 'Spree::AdminUser'
  belongs_to :store, class_name: 'Spree::Store'

  enum :state, {
    pending: 0,
    paid: 1,
    canceled: 2,
    returned: 3
  }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true
  
  # Campo para marcar si es un traspaso entre métodos de pago
  attribute :traspaso, :boolean, default: false

  # Atributos permitidos para búsquedas con Ransack
  def self.ransackable_attributes(auth_object = nil)
    ["amount", "created_at", "current_balance", "description", "id", "id_value", "spree_admin_user_id", "spree_payment_method_id", "state", "store_id", "traspaso", "updated_at"]
  end

  # Asociaciones permitidas para búsquedas con Ransack
  def self.ransackable_associations(auth_object = nil)
    ["spree_admin_user", "spree_payment_method", "store"]
  end
end
