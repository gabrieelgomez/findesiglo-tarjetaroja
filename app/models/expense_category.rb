class ExpenseCategory < ApplicationRecord
  belongs_to :store, class_name: 'Spree::Store'
  has_many :expenses, dependent: :nullify

  enum :category_type, {
    gasto_fijo: 0,
    gasto_variable: 1,
    gasto_inversion: 2,
    gasto_inventario: 3
  }

  validates :name, presence: true, uniqueness: { scope: :store_id }

  scope :ordered, -> { order(:position) }

  CATEGORY_TYPE_LABELS = {
    'gasto_fijo' => 'Gasto Fijo',
    'gasto_variable' => 'Gasto Variable',
    'gasto_inversion' => 'Gasto de Inversión',
    'gasto_inventario' => 'Gasto de Inventario'
  }.freeze

  def type_label
    CATEGORY_TYPE_LABELS[category_type] || category_type.humanize
  end

  def self.ransackable_attributes(auth_object = nil)
    ["category_type", "created_at", "id", "name", "position", "store_id", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["expenses", "store"]
  end
end
