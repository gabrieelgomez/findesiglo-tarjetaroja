module Spree
  module Admin
    class ExpenseReportsController < Spree::Admin::BaseController
      def index
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
        @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
        @category_type_filter = params[:category_type]

        base_scope = current_store.expenses
                          .where(traspaso: false)
                          .where.not(state: :canceled)
                          .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)

        if @category_type_filter.present?
          category_ids = current_store.expense_categories.where(category_type: @category_type_filter).pluck(:id)
          base_scope = base_scope.where(expense_category_id: category_ids)
        end

        @expenses = base_scope.includes(:expense_category, :spree_payment_method).order(created_at: :desc)

        @total_amount = base_scope.sum(:amount)

        @by_category = base_scope
          .joins(:expense_category)
          .group('expense_categories.name')
          .sum(:amount)
          .sort_by { |_, v| -v }

        raw_by_type = base_scope
          .joins(:expense_category)
          .group('expense_categories.category_type')
          .sum(:amount)
        # Normalizar claves: pueden venir como entero (0,1,2,3) o como string del enum ("gasto_fijo", etc.)
        type_to_idx = { 0 => 0, 1 => 1, 2 => 2, 3 => 3, 'gasto_fijo' => 0, 'gasto_variable' => 1, 'gasto_inversion' => 2, 'gasto_inventario' => 3 }
        @by_category_type = { 0 => 0, 1 => 0, 2 => 0, 3 => 0 }
        raw_by_type.each do |key, amount|
          idx = type_to_idx[key] || (key.respond_to?(:to_i) && (0..3).cover?(key.to_i) ? key.to_i : nil)
          @by_category_type[idx] += amount if idx
        end

        @by_payment_method = base_scope
          .joins(:spree_payment_method)
          .group('spree_payment_methods.name')
          .sum(:amount)
          .sort_by { |_, v| -v }

        @uncategorized_total = base_scope.where(expense_category_id: nil).sum(:amount)

        @expense_categories = current_store.expense_categories.ordered
      end
    end
  end
end
