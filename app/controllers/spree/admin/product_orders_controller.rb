module Spree
  module Admin
    class ProductOrdersController < Spree::Admin::BaseController
      before_action :find_product
      before_action :set_date_range
      before_action :set_per_page

      def index
        @orders = fetch_product_orders
        @summary_stats = calculate_summary_stats
      end

      private

      def find_product
        @product = current_store.products.friendly.find(params[:product_id])
      end

      def set_date_range
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 3.months.ago.to_date
        @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
      end

      def set_per_page
        @per_page = (params[:per_page].presence || 25).to_i
        @per_page = 25 if @per_page <= 0 || @per_page > 100
      end

      def fetch_product_orders
        Spree::Order
          .joins(line_items: :variant)
          .where(spree_variants: { product_id: @product.id })
          .where(store_id: current_store.id)
          .where(state: ['complete', 'shipped', 'delivered'])
          .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
          .left_joins(:user)
          .where(*excluded_report_orders_condition)
          .includes(:user, line_items: { variant: :option_values })
          .distinct
          .order(created_at: :desc)
          .page(params[:page])
          .per(@per_page)
      end

      def calculate_summary_stats
        orders = Spree::Order
          .joins(line_items: :variant)
          .where(spree_variants: { product_id: @product.id })
          .where(store_id: current_store.id)
          .where(state: ['complete', 'shipped', 'delivered'])
          .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
          .left_joins(:user)
          .where(*excluded_report_orders_condition)
          .distinct

        line_items = Spree::LineItem
          .joins(:order, :variant)
          .where(spree_variants: { product_id: @product.id })
          .where(spree_orders: {
            store_id: current_store.id,
            state: ['complete', 'shipped', 'delivered'],
            created_at: @start_date.beginning_of_day..@end_date.end_of_day
          })
          .where(order_id: orders.select(:id))

        {
          total_orders: orders.count,
          total_units_sold: line_items.sum(:quantity)
        }
      end

      def excluded_report_orders_condition
        emails = Rails.application.config.x.excluded_report_emails
        return ["1=1"] if emails.blank?
        ["(spree_users.id IS NULL OR spree_users.email NOT IN (?)) AND (spree_orders.email IS NULL OR spree_orders.email NOT IN (?))", emails, emails]
      end
    end
  end
end
