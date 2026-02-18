# frozen_string_literal: true

class CreateVariantChangeLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :variant_change_logs do |t|
      t.references :admin_user, null: false, foreign_key: { to_table: :spree_admin_users }
      t.references :product, null: false, foreign_key: { to_table: :spree_products }
      t.references :variant, null: false, foreign_key: { to_table: :spree_variants }
      t.string :product_name, null: false
      t.string :variant_name, null: false
      t.string :field_name, null: false
      t.text :old_value
      t.text :new_value
      t.string :associated_type
      t.bigint :associated_id
      t.string :source, null: false, default: 'variant_edit' # variant_edit | product_edit
      t.string :request_id # Para agrupar cambios del mismo request
      t.timestamps
    end

    add_index :variant_change_logs, [:product_id, :created_at]
    add_index :variant_change_logs, [:variant_id, :created_at]
    add_index :variant_change_logs, [:admin_user_id, :created_at]
    add_index :variant_change_logs, :request_id
    add_index :variant_change_logs, :created_at
  end
end
