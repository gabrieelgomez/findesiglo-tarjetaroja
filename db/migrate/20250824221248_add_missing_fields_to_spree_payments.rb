class AddMissingFieldsToSpreePayments < ActiveRecord::Migration[8.0]
  def change
    add_column :spree_payments, :referencia, :string
    add_column :spree_payments, :monto_bolivares, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :spree_payments, :traspaso, :boolean, default: false
    add_column :spree_payments, :description, :string
  end
end
