module Spree
  module Admin
    class SoldProductsController < Spree::Admin::BaseController
      include Spree::Admin::Concerns::JsonApiTokenAuthenticatable

      before_action :set_date_range, only: [:index, :export]

      def index
        if try_spree_current_user&.spree_roles&.pluck(:name)&.include?('operator')
          return respond_to do |format|
            format.html { redirect_to spree.admin_orders_path }
            format.json { render json: { error: 'Forbidden' }, status: :forbidden }
          end
        end

        @sold_products = fetch_sold_products
        @summary_stats = calculate_summary_stats

        respond_to do |format|
          format.html
          format.json do
            render json: {
              summary_stats: @summary_stats,
              sold_products: @sold_products.map { |li| sold_product_line_item_json(li) }
            }
          end
        end
      end

      def export
        @sold_products = fetch_sold_products
        @summary_stats = calculate_summary_stats

        respond_to do |format|
          format.xlsx do
            response.headers['Content-Disposition'] = "attachment; filename=\"productos_vendidos_#{@start_date}_#{@end_date}.xlsx\""
          end
        end
      end

      private

      def set_date_range
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
        @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
      end

      def fetch_sold_products
        Spree::LineItem
          .joins(:order, :variant)
          .where(order_id: paid_order_ids)
          .includes(:order, :variant, :product, order: [:user, :payments])
          .order('spree_orders.completed_at DESC')
      end

      def calculate_summary_stats
        line_items = Spree::LineItem.where(order_id: paid_order_ids)

        {
          total_products_sold: line_items.sum(:quantity),
          total_sales_value: line_items.sum('spree_line_items.price * spree_line_items.quantity'),
          total_cost_value: line_items.sum('spree_line_items.cost_price * spree_line_items.quantity')
        }
      end

      def paid_order_ids
        @paid_order_ids ||= Spree::Payment
          .where(state: 'completed')
          .where(updated_at: @start_date.beginning_of_day..@end_date.end_of_day)
          .joins(:order)
          .left_joins(order: :user)
          .where(spree_orders: { store_id: current_store.id, state: ['complete', 'shipped', 'delivered'] })
          .where(*excluded_report_orders_condition)
          .pluck(:order_id)
          .uniq
      end

      def excluded_report_orders_condition
        emails = Rails.application.config.x.excluded_report_emails
        return ["1=1"] if emails.blank?
        ["(spree_users.id IS NULL OR spree_users.email NOT IN (?)) AND (spree_orders.email IS NULL OR spree_orders.email NOT IN (?))", emails, emails]
      end

      def sold_product_line_item_json(line_item)
        {
          id: line_item.id,
          product_id: line_item.product_id,
          product_name: line_item.product&.name,
          variant_id: line_item.variant_id,
          variant_name: line_item.variant&.name,
          quantity: line_item.quantity,
          price: line_item.price.to_f,
          cost_price: line_item.cost_price.to_f,
          order_number: line_item.order&.number,
          order_id: line_item.order_id,
          completed_at: line_item.order&.completed_at&.iso8601
        }
      end
    end
  end
end
