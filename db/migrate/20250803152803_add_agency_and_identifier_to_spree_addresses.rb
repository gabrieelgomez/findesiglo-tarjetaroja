class AddAgencyAndIdentifierToSpreeAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :spree_addresses, :agency, :string
    add_column :spree_addresses, :identifier, :string
  end
end
