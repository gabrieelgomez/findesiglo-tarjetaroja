class RenameSpreeUserIdToSpreeAdminUserIdInExpenses < ActiveRecord::Migration[8.0]
  def change
    rename_column :expenses, :spree_user_id, :spree_admin_user_id
    remove_foreign_key :expenses, column: :spree_admin_user_id
    add_foreign_key :expenses, :spree_admin_users, column: :spree_admin_user_id
  end
end
