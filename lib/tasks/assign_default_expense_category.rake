namespace :expenses do
  desc "Asigna la categoría 'Sin Categoría' a todos los egresos que no tienen categoría"
  task assign_default_category: :environment do
    Spree::Store.find_each do |store|
      default_category = store.expense_categories.find_by(name: 'Sin Categoría')

      unless default_category
        puts "Store '#{store.name}' no tiene categoría 'Sin Categoría'. Creándola..."
        default_category = store.expense_categories.create!(
          name: 'Sin Categoría',
          category_type: :gasto_fijo,
          position: 0
        )
      end

      expenses_without_category = store.expenses.where(expense_category_id: nil)
      count = expenses_without_category.count

      if count > 0
        expenses_without_category.update_all(expense_category_id: default_category.id)
        puts "Store '#{store.name}': #{count} egresos asignados a 'Sin Categoría'"
      else
        puts "Store '#{store.name}': todos los egresos ya tienen categoría"
      end
    end

    puts "¡Listo!"
  end
end
