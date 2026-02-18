class AddTraspasoToExpenses < ActiveRecord::Migration[8.0]
  def change
    add_column :expenses, :traspaso, :boolean, default: false
  end
end
