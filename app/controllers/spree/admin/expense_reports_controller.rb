module Spree
  module Admin
    class ExpenseReportsController < Spree::Admin::BaseController
      before_action :set_filters
      before_action :load_report_data

      def index
        @expense_categories = current_store.expense_categories.ordered
        @category_filter = if @category_filter_id == 'uncategorized'
                             :uncategorized
                           elsif @category_filter_id.present?
                             current_store.expense_categories.find_by(id: @category_filter_id)
                           end
      end

      def export
        respond_to do |format|
          format.xlsx do
            response.headers['Content-Disposition'] = "attachment; filename=\"reporte_egresos_#{@start_date}_#{@end_date}.xlsx\""
          end
        end
      end

      private

      def set_filters
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
        @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
        @category_type_filter = params[:category_type]
        @exclude_inventory = params[:exclude_inventory].present?
        @category_filter_id = params[:category_id].presence
      end

      def load_report_data
        base_scope = filtered_scope

        @expenses = base_scope.includes(:expense_category, :spree_payment_method).order(created_at: :desc)
        @total_amount = base_scope.sum(:amount)

        by_cat_raw = base_scope.joins(:expense_category).group('expense_categories.id', 'expense_categories.name').sum(:amount)
        @by_category = by_cat_raw.sort_by { |_, v| -v }

        raw_by_type = base_scope
          .joins(:expense_category)
          .group('expense_categories.category_type')
          .sum(:amount)

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
      end

      def filtered_scope
        scope = current_store.expenses
                    .where(traspaso: false)
                    .where.not(state: :canceled)
                    .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)

        if @exclude_inventory
          inventario_ids = current_store.expense_categories.where(category_type: :gasto_inventario).pluck(:id)
          scope = scope.where(
            "expenses.expense_category_id IS NULL OR expenses.expense_category_id NOT IN (?)",
            inventario_ids.presence || [0]
          )
        end

        if @category_type_filter.present?
          category_ids = current_store.expense_categories.where(category_type: @category_type_filter).pluck(:id)
          scope = scope.where(expense_category_id: category_ids)
        end

        if @category_filter_id.present?
          if @category_filter_id == 'uncategorized'
            scope = scope.where(expense_category_id: nil)
          else
            scope = scope.where(expense_category_id: @category_filter_id)
          end
        end

        scope
      end
    end
  end
end
