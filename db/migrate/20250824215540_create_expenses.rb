class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.decimal :amount, precision: 10, scale: 2, default: 0
      t.integer :state, default: 0
      t.decimal :current_balance, precision: 10, scale: 2, default: 0
      t.text :description
      t.references :spree_payment_method, null: false, foreign_key: { to_table: 'spree_payment_methods' }
      t.references :spree_user, null: false, foreign_key: { to_table: 'spree_users' }

      t.timestamps
    end
  end
end
