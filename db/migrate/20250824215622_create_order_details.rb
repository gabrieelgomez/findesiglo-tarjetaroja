class CreateOrderDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :order_details do |t|
      t.text :description
      t.string :description_short
      t.integer :operator
      t.integer :type_service, default: 0
      t.datetime :delivery_time
      t.string :spree_order_number
      t.references :spree_order, null: false, foreign_key: { to_table: 'spree_orders' }

      t.timestamps
    end

    add_index(:order_details, [:spree_order_id],
      name: 'order_details_join_index',
      unique: true)
  end
end
