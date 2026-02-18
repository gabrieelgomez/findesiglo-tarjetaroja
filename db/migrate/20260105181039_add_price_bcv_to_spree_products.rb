class AddPriceBcvToSpreeProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :spree_products, :price_bcv, :decimal, precision: 10, scale: 2
  end
end
