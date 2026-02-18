class CreateBcvs < ActiveRecord::Migration[8.0]
  def change
    create_table :bcvs do |t|
      t.float :value

      t.timestamps
    end
  end
end
