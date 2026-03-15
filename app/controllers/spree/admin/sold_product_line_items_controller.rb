module Spree
  module Admin
    class SoldProductLineItemsController < Spree::Admin::BaseController
      before_action :load_line_item

      def edit; end

      def update
        if @line_item.update(line_item_params)
          flash[:success] = I18n.t(:line_item_updated_successfully)
          redirect_to spree.admin_sold_products_path
        else
          flash.now[:error] = @line_item.errors.full_messages.to_sentence
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def load_line_item
        @line_item = Spree::LineItem.find(params[:id])
      end

      def line_item_params
        params.require(:line_item).permit(:quantity, :price, :cost_price, :currency, :tax_category_id)
      end
    end
  end
end
