class AddStoreIdToExpenses < ActiveRecord::Migration[8.0]
  def change
    add_reference :expenses, :store, null: true, foreign_key: { to_table: :spree_stores }
    
    # Asignar todos los expenses existentes a la primera tienda (Shop)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE expenses SET store_id = (SELECT id FROM spree_stores ORDER BY id LIMIT 1) WHERE store_id IS NULL
        SQL
      end
    end
    
    # Ahora que todos tienen store_id, hacerlo NOT NULL
    change_column_null :expenses, :store_id, false
  end
end
