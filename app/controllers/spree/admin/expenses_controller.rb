module Spree
  module Admin
    class ExpensesController < Spree::Admin::BaseController
      before_action :load_expense, only: [:edit, :update, :destroy]

      def index
        @expenses = current_store.expenses
                          .includes(:spree_payment_method, :spree_admin_user)
                          .ransack(params[:q])
                          .result
                          .page(params[:page])
                          .per(params[:per_page] || 25)
      end

      def new
        @expense = Expense.new(state: 'paid')
      end

      def create
        @expense = Expense.new(expense_params)
        @expense.spree_admin_user = try_spree_current_user
        @expense.store = current_store

        if @expense.save
          redirect_to admin_transactions_url, notice: 'Gasto creado exitosamente'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @expense.update(expense_params)
          redirect_to admin_transactions_url, notice: 'Gasto actualizado exitosamente'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @expense.destroy
          redirect_to admin_transactions_url, notice: 'Gasto borrado exitosamente'
        else
          redirect_to admin_transactions_url, alert: 'Gasto no pudo ser borrado'
        end
      end

      private

      def load_expense
        @expense = current_store.expenses.find(params[:id])
      end

      def expense_params
        params.require(:expense).permit(:amount, :state, :current_balance, :description, :spree_payment_method_id, :traspaso)
      end
    end
  end
end 