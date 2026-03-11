# frozen_string_literal: true

class AddAdminUserIdToSpreeStateChanges < ActiveRecord::Migration[7.0]
  def change
    return if column_exists?(:spree_state_changes, :admin_user_id)

    add_reference :spree_state_changes, :admin_user,
                  foreign_key: { to_table: :spree_admin_users },
                  index: true
  end
end
