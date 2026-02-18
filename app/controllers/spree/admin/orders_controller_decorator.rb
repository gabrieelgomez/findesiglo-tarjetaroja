module Spree
  module Admin
    module OrdersControllerDecorator
      def self.prepended(base)
        base.class_eval do
          # Agregar métodos para adjustments
          def open_adjustments
            @order = Spree::Order.find_by!(number: params[:id])
            @order.adjustments.update_all(eligible: true)
            @order.reload.update_with_updater!
            
            flash[:success] = Spree.t(:all_adjustments_opened)
            redirect_to admin_order_adjustments_path(@order)
          end

          def close_adjustments
            @order = Spree::Order.find_by!(number: params[:id])
            @order.adjustments.update_all(eligible: false)
            @order.reload.update_with_updater!
            
            flash[:success] = Spree.t(:all_adjustments_closed)
            redirect_to admin_order_adjustments_path(@order)
          end
        end
      end
    end
  end
end

::Spree::Admin::OrdersController.prepend Spree::Admin::OrdersControllerDecorator if ::Spree::Admin::OrdersController.included_modules.exclude?(Spree::Admin::OrdersControllerDecorator) 