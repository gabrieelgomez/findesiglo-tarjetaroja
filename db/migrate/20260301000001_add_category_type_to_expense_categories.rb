class AddCategoryTypeToExpenseCategories < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:expense_categories)

    unless column_exists?(:expense_categories, :category_type)
      add_column :expense_categories, :category_type, :integer, default: 0, null: false
      add_index :expense_categories, :category_type
    end
  end
end
