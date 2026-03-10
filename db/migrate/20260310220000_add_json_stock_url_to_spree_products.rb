class AddJsonStockUrlToSpreeProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :spree_products, :json_stock_url, :string
  end
end
