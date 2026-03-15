module Spree
  module Admin
    class SoldProductLineItemsController < Spree::Admin::BaseController
      before_action :load_line_item

      def edit; end

      def update
        attrs = line_item_params.to_h.select { |_, v| v.present? }
        @line_item.update_columns(attrs.transform_values { |v| v.to_f })
        flash[:success] = I18n.t(:line_item_updated_successfully)
        redirect_to spree.admin_sold_products_path
      rescue => e
        flash.now[:error] = e.message
        render :edit, status: :unprocessable_entity
      end

      private

      def load_line_item
        @line_item = Spree::LineItem.find(params[:id])
      end

      def line_item_params
        params.require(:line_item).permit(:price, :cost_price)
      end
    end
  end
end
