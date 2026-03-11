module Spree
  module Admin
    module OrdersHelper
      TaxLine = Struct.new(:label, :display_amount, :item, :for_shipment, keyword_init: true) do
        def name
          item_name = item.name
          item_name += " #{Spree.t(:shipment).downcase}" if for_shipment

          "#{label} (#{item_name})"
        end
      end

      def order_summary_tax_lines_additional(order)
        line_item_taxes = order.line_item_adjustments.tax.map { |tax_adjustment| map_to_tax_line(tax_adjustment) }
        shipment_taxes = order.shipment_adjustments.tax.map { |tax_adjustment| map_to_tax_line(tax_adjustment, for_shipment: true) }

        line_item_taxes + shipment_taxes
      end

      def order_shipment_state(order, options = {})
        shipment_state(order.shipment_state, options)
      end

      def payment_state_badge(state)
        content_tag :span, class: "badge badge-#{state}" do
          if state == 'completed'
            icon('check') + Spree.t('payment_states.completed')
          elsif state == 'failed'
            icon('cancel') + Spree.t('payment_states.failed')
          elsif state == 'processing'
            icon('progress') + Spree.t('payment_states.processing')
          else
            Spree.t("payment_states.#{state}")
          end
        end
      end

      def line_item_shipment_price(line_item, quantity)
        Spree::Money.new(line_item.price * quantity, currency: line_item.currency)
      end

      def ready_to_ship_orders_count
        return 0 unless respond_to?(:current_store) && respond_to?(:current_ability)
        current_store.orders.accessible_by(current_ability, :index).complete
          .where.not(shipment_state: 'shipped')
          .where.not(state: %w[canceled partially_canceled])
          .count
      rescue
        0
      end

      def order_filter_dropdown_value
        q = params[:q] || {}
        return Spree.t('admin.orders.all_orders') if q.values_at(*%w[payment_state_not_eq shipment_state_not_in shipment_state_eq state_eq state_in refunded partially_refunded]).all?(&:blank?)
        return Spree.t('admin.orders.unfulfilled') if q[:shipment_state_not_in] == ['shipped', 'canceled'] || q[:shipment_state_not_in] == %w[shipped canceled]
        return Spree.t('admin.orders.fulfilled') if q[:shipment_state_eq].to_s == 'shipped'
        return Spree.t('admin.orders.canceled') if q[:state_in].to_s.include?('canceled')
        return Spree.t('admin.orders.refunded') if q[:refunded].present?
        return Spree.t('admin.orders.partially_refunded') if q[:partially_refunded].present?
        Spree.t('admin.orders.all_orders')
      end

      def order_payment_state(order, options = {})
        return if order.payment_state.blank?

        content_tag :span, class: "badge  #{options[:class]} badge-#{order.partially_refunded? ? 'warning' : order.payment_state}" do
          if order.order_refunded?
            icon('credit-card-refund') + Spree.t('payment_states.refunded')
          elsif order.partially_refunded?
            icon('credit-card-refund') + Spree.t('payment_states.partially_refunded')
          elsif order.payment_state == 'failed'
            icon('cancel') + Spree.t('payment_states.failed')
          elsif order.payment_state == 'void'
            icon('cancel') + Spree.t('payment_states.void')
          elsif order.payment_state == 'paid'
            icon('check') + Spree.t('payment_states.paid')
          else
            icon('progress') + Spree.t("payment_states.#{order.payment_state}")
          end
        end
      end

      def shipment_state(shipment_state, options = {})
        return if shipment_state.blank?

        badge_class = case shipment_state
                      when 'shipped'   then 'badge-shipped'
                      when 'partial'   then 'badge-partial'
                      when 'canceled'  then 'badge-canceled'
                      when 'ready'     then 'badge-ready'
                      when 'apartado'  then 'badge-apartado'
                      when 'fabricado' then 'badge-fabricado'
                      when 'empacado'  then 'badge-empacado'
                      else 'badge-pending'
                      end

        icon_name = case shipment_state
                    when 'shipped'   then 'truck-delivery'
                    when 'partial'   then 'progress-check'
                    when 'canceled'  then 'x'
                    when 'ready'     then 'circle-check'
                    when 'apartado'  then 'hand-stop'
                    when 'fabricado' then 'shirt'
                    when 'empacado'  then 'package'
                    else 'progress'
                    end

        content_tag :span, class: "badge #{options[:class]} #{badge_class}" do
          icon(icon_name) + Spree.t("shipment_states.#{shipment_state}")
        end
      end

      private

      def map_to_tax_line(tax_adjustment, for_shipment: false)
        TaxLine.new(
          label: tax_adjustment.label,
          display_amount: tax_adjustment.display_amount,
          item: tax_adjustment.adjustable,
          for_shipment: for_shipment
        )
      end
    end
  end
end
