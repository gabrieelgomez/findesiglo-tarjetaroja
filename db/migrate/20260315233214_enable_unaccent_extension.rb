class EnableUnaccentExtension < ActiveRecord::Migration[8.0]
  def up
    enable_extension 'unaccent'
  end

  def down
    disable_extension 'unaccent'
  end
end
