module Spree
  module Admin
    class TopVariantsController < Spree::Admin::BaseController
      before_action :set_date_range
      before_action :set_per_page

      def index
        @top_variants = fetch_top_variants
        @summary_stats = calculate_summary_stats
      end

      private

      def set_date_range
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 3.months.ago.to_date
        @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
      end

      def set_per_page
        @per_page = (params[:per_page].presence || 50).to_i
        @per_page = 50 if @per_page <= 0 || @per_page > 200
      end

      def fetch_top_variants
        order_ids = paid_order_ids

        Spree::Variant
          .joins(:line_items, :product)
          .joins("INNER JOIN spree_products_stores ON spree_products_stores.product_id = spree_products.id")
          .where(spree_products_stores: { store_id: current_store.id })
          .where(spree_line_items: { order_id: order_ids })
          .select(
            "spree_variants.*",
            "SUM(spree_line_items.quantity) as total_quantity"
          )
          .group("spree_variants.id")
          .order("total_quantity DESC")
          .page(params[:page])
          .per(@per_page)
      end

      def calculate_summary_stats
        order_ids = paid_order_ids

        line_items = Spree::LineItem
          .joins(variant: :product)
          .joins("INNER JOIN spree_products_stores ON spree_products_stores.product_id = spree_products.id")
          .where(spree_products_stores: { store_id: current_store.id })
          .where(order_id: order_ids)

        {
          total_units_sold: line_items.sum(:quantity),
          total_variants: line_items.select("DISTINCT spree_variants.id").count
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
