class SeedDefaultExpenseCategories < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:expense_categories)

    Spree::Store.find_each do |store|
      categories = [
        { name: 'Sin Categoría',              category_type: 0, position: 0 },
        { name: 'Nómina',                     category_type: 0, position: 1 },
        { name: 'Condominio',                 category_type: 0, position: 2 },
        { name: 'Internet',                   category_type: 0, position: 3 },
        { name: 'Electricidad',               category_type: 0, position: 4 },
        { name: 'Agua',                       category_type: 0, position: 5 },
        { name: 'Alquiler',                   category_type: 0, position: 6 },
        { name: 'Gastos Operativos Oficina',  category_type: 1, position: 7 },
        { name: 'Suministros',                category_type: 1, position: 8 },
        { name: 'Transporte y Envíos',        category_type: 1, position: 9 },
        { name: 'Publicidad y Marketing',     category_type: 1, position: 10 },
        { name: 'Mantenimiento',              category_type: 1, position: 11 },
        { name: 'Comisiones Bancarias',       category_type: 1, position: 12 },
        { name: 'Impuestos',                  category_type: 0, position: 13 },
        { name: 'Seguros',                    category_type: 0, position: 14 },
        { name: 'Inversiones',                category_type: 2, position: 15 },
        { name: 'Equipos y Tecnología',       category_type: 2, position: 16 },
        { name: 'Mobiliario',                 category_type: 2, position: 17 },
        { name: 'Otros',                      category_type: 1, position: 18 },
        { name: 'Inventario',                 category_type: 3, position: 19 },
      ]

      categories.each do |cat_attrs|
        ExpenseCategory.find_or_create_by!(store: store, name: cat_attrs[:name]) do |cat|
          cat.category_type = cat_attrs[:category_type]
          cat.position = cat_attrs[:position]
        end
      end
    end
  end

  def down
    ExpenseCategory.where(name: [
      'Sin Categoría', 'Nómina', 'Condominio', 'Internet', 'Electricidad',
      'Agua', 'Alquiler', 'Gastos Operativos Oficina', 'Suministros',
      'Transporte y Envíos', 'Publicidad y Marketing', 'Mantenimiento',
      'Comisiones Bancarias', 'Impuestos', 'Seguros', 'Inversiones',
      'Equipos y Tecnología', 'Mobiliario', 'Otros', 'Inventario'
    ]).destroy_all
  end
end
