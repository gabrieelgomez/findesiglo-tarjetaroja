class Expense < ApplicationRecord
  belongs_to :spree_payment_method, class_name: 'Spree::PaymentMethod'
  belongs_to :spree_admin_user, class_name: 'Spree::AdminUser'
  belongs_to :store, class_name: 'Spree::Store'
  belongs_to :expense_category, optional: true

  enum :state, {
    pending: 0,
    paid: 1,
    canceled: 2,
    returned: 3
  }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true

  attribute :traspaso, :boolean, default: false

  def self.ransackable_attributes(auth_object = nil)
    ["amount", "created_at", "current_balance", "description", "expense_category_id", "id", "id_value", "spree_admin_user_id", "spree_payment_method_id", "state", "store_id", "traspaso", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["expense_category", "spree_admin_user", "spree_payment_method", "store"]
  end
end
