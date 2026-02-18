class AddColumnValueWhatsappToBcvs < ActiveRecord::Migration[8.0]
  def change
    add_column :bcvs, :value_whatsapp, :float
  end
end
