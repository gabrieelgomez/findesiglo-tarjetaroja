module Spree
  module Admin
    class AdjustmentsController < ResourceController
      belongs_to 'spree/order', find_by: :number

      create.after :update_totals
      destroy.after :update_totals
      update.after :update_totals

      skip_before_action :load_resource, only: [:toggle_state, :edit, :update, :destroy]

      before_action :find_adjustment, only: [:destroy, :edit, :update]

      after_action :delete_promotion_from_order, only: [:destroy], if: -> { @adjustment.destroyed? && @adjustment.promotion? }

      def index
        @adjustments = @order.all_adjustments.eligible.order(created_at: :asc)
      end

      def toggle_state
        @adjustment = @order.all_adjustments.find(params[:id])
        @adjustment.update!(eligible: !@adjustment.eligible?)
        @order.reload.update_with_updater!
        
        if @adjustment.eligible?
          flash[:success] = Spree.t(:adjustment_successfully_opened)
        else
          flash[:success] = Spree.t(:adjustment_successfully_closed)
        end
        
        redirect_to admin_order_adjustments_path(@order)
      end

      private

      def find_adjustment
        # Need to assign to @object here to keep ResourceController happy
        @adjustment = @object = parent.all_adjustments.find(params[:id])
      end

      def update_totals
        @order.reload.update_with_updater!
      end

      # Override method used to create a new instance to correctly
      # associate adjustment with order
      def build_resource
        parent.adjustments.build(order: parent)
      end

      def delete_promotion_from_order
        return if @adjustment.source.nil?

        @order.promotions.delete(@adjustment.source.promotion)
      end

      def permitted_resource_params
        params.require(:adjustment).permit(:amount, :label)
      end
      
      # Redirigir a la orden después de crear/actualizar
      def location_after_create
        spree.edit_admin_order_path(@order)
      end
      
      def location_after_update
        spree.edit_admin_order_path(@order)
      end
      
      # Mensaje personalizado después de crear
      def message_after_create
        Spree.t(:adjustment_successfully_created)
      end
      
      # Mensaje personalizado después de eliminar
      def message_after_destroy
        Spree.t(:adjustment_successfully_deleted)
      end
    end
  end
end 