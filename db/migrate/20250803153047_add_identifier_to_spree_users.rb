class AddIdentifierToSpreeUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :spree_users, :identifier, :string
  end
end
