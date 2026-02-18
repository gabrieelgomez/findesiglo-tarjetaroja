namespace :expenses do
  desc "Asignar todos los expenses al store 1 (Shop)"
  task assign_to_store_1: :environment do
    store = Spree::Store.find(1)
    
    updated_count = Expense.where.not(store_id: store.id).update_all(store_id: store.id)
    
    puts "#{updated_count} expenses actualizados al store '#{store.name}' (ID: #{store.id})"
    puts "Total de expenses en store 1: #{store.expenses.count}"
  end
end
