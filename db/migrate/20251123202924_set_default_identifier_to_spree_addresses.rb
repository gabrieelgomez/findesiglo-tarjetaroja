class SetDefaultIdentifierToSpreeAddresses < ActiveRecord::Migration[8.0]
  def up
    # Establecer el valor por defecto en la base de datos
    change_column_default :spree_addresses, :agency, "MRW"
  end

  def down
    # Revertir el valor por defecto
    change_column_default :spree_addresses, :agency, nil
  end
end
