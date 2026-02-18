# frozen_string_literal: true

class AddCompletedByToSpreeOrders < ActiveRecord::Migration[7.0]
  def change
    return unless table_exists?(:spree_orders)

    add_reference :spree_orders, :completed_by,
                  foreign_key: { to_table: :spree_admin_users },
                  index: { name: "index_spree_orders_on_completed_by_id" }
  end
end
