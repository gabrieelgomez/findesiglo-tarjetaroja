# Crear tabla expense_categories y referencia en expenses.
# Debe ejecutarse antes de AddCategoryTypeToExpenseCategories (20260301000001).
class CreateExpenseCategories < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:expense_categories)

    create_table :expense_categories do |t|
      t.string :name, null: false
      t.integer :position, default: 0
      t.references :store, null: false, foreign_key: { to_table: 'spree_stores' }

      t.timestamps
    end

    add_index :expense_categories, [:store_id, :name], unique: true
    add_index :expense_categories, [:store_id, :position]

    return if column_exists?(:expenses, :expense_category_id)

    add_reference :expenses, :expense_category, foreign_key: true
  end
end
