class AddCompletedToSpreeOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :spree_orders, :completed, :boolean
  end
end
