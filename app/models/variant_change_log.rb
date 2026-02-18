# frozen_string_literal: true

class VariantChangeLog < ApplicationRecord
  belongs_to :admin_user, class_name: 'Spree::AdminUser'
  belongs_to :product, class_name: 'Spree::Product'
  belongs_to :variant, class_name: 'Spree::Variant'

  SOURCES = %w[variant_edit product_edit].freeze

  validates :field_name, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_request, ->(request_id) { where(request_id: request_id) }

  # Etiquetas amigables para nombres de campos
  FIELD_LABELS = {
    'sku' => 'Código (SKU)',
    'barcode' => 'Código de barras',
    'cost_price' => 'Precio de costo',
    'tax_category_id' => 'Categoría fiscal',
    'discontinue_on' => 'Fecha de discontinuación',
    'track_inventory' => 'Rastrear inventario',
    'weight' => 'Peso',
    'height' => 'Alto',
    'width' => 'Ancho',
    'depth' => 'Profundidad',
    'amount' => 'Precio',
    'compare_at_amount' => 'Precio comparación',
    'count_on_hand' => 'Cantidad en stock',
    'backorderable' => 'Permitir pedido pendiente'
  }.freeze

  def self.field_label(field_name)
    FIELD_LABELS[field_name.to_s] || field_name.to_s.humanize
  end

  def field_label
    self.class.field_label(field_name)
  end

  def description
    if old_value.blank? && new_value.present?
      "Campo #{field_label} establecido en #{new_value}"
    elsif old_value.present? && new_value.blank?
      "Campo #{field_label} eliminado (era #{old_value})"
    else
      "Campo #{field_label} cambiado de #{old_value} a #{new_value}"
    end
  end
end
