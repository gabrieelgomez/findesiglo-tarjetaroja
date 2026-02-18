module Spree
  module Admin
    class TransactionsController < Spree::Admin::BaseController
      def index
        return redirect_to spree.admin_orders_path if try_spree_current_user.spree_roles.pluck(:name).include?('operator')

        params[:q] ||= {}

        # Store original date params
        created_at_gt = params[:q][:created_at_gt]
        created_at_lt = params[:q][:created_at_lt]

        # Parse and format date parameters
        if params[:q][:created_at_gt].present?
          params[:q][:created_at_gt] = begin
            Time.zone.parse(params[:q][:created_at_gt]).beginning_of_day
          rescue StandardError
            ''
          end
        end

        if params[:q][:created_at_lt].present?
          params[:q][:created_at_lt] = begin
            Time.zone.parse(params[:q][:created_at_lt]).end_of_day
          rescue StandardError
            ''
          end
        end

        # Get filtered payments and expenses
        @payments = payments_completed
        @expenses = expenses_paid

        # Apply date filters if specified
        if params[:q][:created_at_gt].present? || params[:q][:created_at_lt].present?
          @payments = @payments.ransack(params[:q]).result
          @expenses = @expenses.ransack(params[:q]).result
        end

        # Filter traspasos based on the selected option
        if params[:q][:traspaso_eq].present?
          case params[:q][:traspaso_eq]
          when 'true'
            # Show only traspasos
            @payments = @payments.where(traspaso: true)
            @expenses = @expenses.where(traspaso: true)
          when 'false'
            # Show only non-traspasos
            @payments = @payments.where(traspaso: false)
            @expenses = @expenses.where(traspaso: false)
          end
        end

        # Filter by transaction type (ingresos/egresos)
        if params[:q][:transaction_type].present?
          case params[:q][:transaction_type]
          when 'ingresos'
            # Show only payments (ingresos) - keep all existing filters
            @expenses = Expense.none
          when 'egresos'
            # Show only expenses (egresos) - keep all existing filters
            @payments = Spree::Payment.none
          end
        end

        # Order by created_at descending
        @payments = @payments.reorder(created_at: :desc)
        @expenses = @expenses.order(created_at: :desc)

        # Combine and sort transactions
        transactions = (@payments + @expenses).sort_by(&:created_at).reverse

        @transactions = Kaminari.paginate_array(transactions).page(params[:page]).per(per_page)

        # Initialize search object for the form - preserve all existing params
        @search = Expense.ransack(params[:q])
      end

      def daily_balance
        return redirect_to spree.admin_orders_path if try_spree_current_user.spree_roles.pluck(:name).include?('operator')

        params[:q] ||= {}

        # As date params are deleted if @show_only_completed, store
        # the original date so we can restore them into the params
        # after the search
        created_at_gt = params[:q][:created_at_gt]
        created_at_lt = params[:q][:created_at_lt]

        if params[:q][:created_at_gt].present?
          params[:q][:created_at_gt] = begin
            Time.zone.parse(params[:q][:created_at_gt]).beginning_of_day
          rescue StandardError
            ''
          end
        end

        if params[:q][:created_at_lt].present?
          params[:q][:created_at_lt] = begin
            Time.zone.parse(params[:q][:created_at_lt]).end_of_day
          rescue StandardError
            ''
          end
        end

        @payments = payments_completed
        @expenses = expenses_paid.ransack(params[:q]).result

        # Initialize search object for the form
        @search = Expense.ransack(params[:q])

        # Filter traspasos based on the selected option
        if params[:q][:traspaso_eq].present?
          case params[:q][:traspaso_eq]
          when 'true'
            # Show only traspasos
            @payments = @payments.where(traspaso: true)
            @expenses = @expenses.where(traspaso: true)
          when 'false'
            # Show only non-traspasos
            @payments = @payments.where(traspaso: false)
            @expenses = @expenses.where(traspaso: false)
          end
        end

        # Filter payments by date range if specified
        if params[:q][:created_at_gt].present? || params[:q][:created_at_lt].present?
          @payments = @payments.ransack(params[:q]).result
        end

        # Ordenar payments y expenses por created_at descendente
        # Usar .reorder para sobrescribir cualquier ordenamiento previo (ej. de ransack)
        # Pre-cargar orders y line_items para optimizar consultas
        @payments = @payments.includes(order: :line_items).reorder(created_at: :desc)
        @expenses = @expenses.order(created_at: :desc)

        # Combinar y mantener el orden descendente (más recientes primero)
        @transactions = (@payments + @expenses).sort_by(&:created_at).reverse

        # Calcular total de camisas vendidas del día
        # Obtener órdenes únicas para evitar duplicar el conteo cuando una orden tiene múltiples pagos
        unique_orders = @payments.map(&:order).compact.uniq
        @total_shirts_sold = unique_orders.sum do |order|
          order.line_items.sum(&:quantity)
        end

        @current_date = created_at_gt
        @previous_day = Date.parse(@current_date) - 1.day if @current_date.present?
        @next_day = Date.parse(@current_date) + 1.day if @current_date.present?
      end

      private

      def per_page
        params[:per_page] || 25
      end

      def payments_completed
        current_store.payments.where(state: 'completed')
      end

      def expenses_paid
        Expense.where(state: 'paid', store_id: current_store.id)
      end
    end
  end
end 