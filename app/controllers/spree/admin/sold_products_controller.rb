module Spree
  module Admin
    class SoldProductsController < Spree::Admin::BaseController
      before_action :set_date_range, only: [:index]

      def index
        return redirect_to spree.admin_orders_path if try_spree_current_user.spree_roles.pluck(:name).include?('operator')

        @sold_products = fetch_sold_products
        @summary_stats = calculate_summary_stats
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
    end
  end
end
