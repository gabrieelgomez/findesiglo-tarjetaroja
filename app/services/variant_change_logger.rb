# frozen_string_literal: true

# Servicio para registrar cambios de STOCK en variantes (desde edit de variante o edit de producto).
# Solo seguimiento de: cantidad en stock (count_on_hand) y permitir backorder (backorderable).
class VariantChangeLogger
  STOCK_FIELDS = %w[count_on_hand backorderable].freeze

  class << self
    # Snapshot solo del stock actual del variant para comparar después.
    def snapshot(variant)
      return {} unless variant&.persisted?

      before_stock_items = variant.stock_items.reload.map do |s|
        {
          stock_location_id: s.stock_location_id,
          count_on_hand: s.count_on_hand,
          backorderable: s.backorderable
        }
      end
      {
        before: {},
        before_prices: [],
        before_stock_items: before_stock_items
      }
    end

    # Registra solo cambios de stock cuando ya tenemos el "antes" y "después".
    def log_from_diff(variant, admin_user:, source: 'product_edit', request_id: nil,
                      before: nil, before_prices: nil, before_stock_items: nil)
      before_stock_items = before_stock_items || []
      return unless admin_user && variant&.persisted?

      product = variant.product
      product_name = product&.name || "Producto ##{variant.product_id}"
      variant_name = variant.human_name.presence || "Variante ##{variant.id}"
      request_id ||= SecureRandom.uuid

      entries = []

      # Solo stock items: count_on_hand y backorderable
      variant.stock_items.reload.each do |stock_item|
        prev = before_stock_items.find { |s| s[:stock_location_id] == stock_item.stock_location_id }
        next unless prev

        if prev[:count_on_hand].to_s != stock_item.count_on_hand.to_s
          entries << {
            field_name: 'count_on_hand',
            old_value: format_value('count_on_hand', prev[:count_on_hand]),
            new_value: format_value('count_on_hand', stock_item.count_on_hand),
            associated_type: 'Spree::StockItem',
            associated_id: stock_item.id
          }
        end
        if prev[:backorderable].to_s != stock_item.backorderable.to_s
          entries << {
            field_name: 'backorderable',
            old_value: format_value('backorderable', prev[:backorderable]),
            new_value: format_value('backorderable', stock_item.backorderable),
            associated_type: 'Spree::StockItem',
            associated_id: stock_item.id
          }
        end
      end

      return if entries.empty?

      create_log_entries(
        variant: variant,
        product: product,
        product_name: product_name,
        variant_name: variant_name,
        admin_user: admin_user,
        source: source,
        request_id: request_id,
        entries: entries
      )
    end

    private

    def format_value(attr, value)
      return '' if value.nil?
      return (value ? 'Sí' : 'No') if value.is_a?(TrueClass) || value.is_a?(FalseClass)
      value.to_s
    end

    def create_log_entries(variant:, product:, product_name:, variant_name:, admin_user:, source:, request_id:, entries:)
      entries.each do |e|
        VariantChangeLog.create!(
          admin_user_id: admin_user.id,
          product_id: product.id,
          variant_id: variant.id,
          product_name: product_name,
          variant_name: variant_name,
          field_name: e[:field_name],
          old_value: e[:old_value],
          new_value: e[:new_value],
          associated_type: e[:associated_type],
          associated_id: e[:associated_id],
          source: source,
          request_id: request_id
        )
      end
    end
  end
end
