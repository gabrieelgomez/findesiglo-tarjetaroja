module Spree
  module Admin
    class ExpenseCategoriesController < Spree::Admin::BaseController
      before_action :load_category, only: [:edit, :update, :destroy]

      def index
        @expense_categories = current_store.expense_categories.ordered
      end

      def new
        @expense_category = ExpenseCategory.new
      end

      def create
        @expense_category = ExpenseCategory.new(category_params)
        @expense_category.store = current_store

        if @expense_category.save
          redirect_to admin_expense_categories_path, notice: 'Categoría creada exitosamente'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @expense_category.update(category_params)
          redirect_to admin_expense_categories_path, notice: 'Categoría actualizada exitosamente'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        default_category = current_store.expense_categories.find_by(name: 'Sin Categoría')
        if @expense_category == default_category
          redirect_to admin_expense_categories_path, alert: 'No se puede eliminar la categoría por defecto'
          return
        end

        @expense_category.expenses.update_all(expense_category_id: default_category&.id)
        @expense_category.destroy
        redirect_to admin_expense_categories_path, notice: 'Categoría eliminada exitosamente'
      end

      private

      def load_category
        @expense_category = current_store.expense_categories.find(params[:id])
      end

      def category_params
        params.require(:expense_category).permit(:name, :category_type, :position)
      end
    end
  end
end
