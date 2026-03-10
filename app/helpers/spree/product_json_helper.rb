module Spree
  module ProductJsonHelper
    def product_as_json(product)
      variants = product.has_variants? ? product.variants.includes(:prices, :images, :option_values, stock_items: :stock_location).order(:position) : []
      master = product.master

      store = product.stores.first

      {
        store: store ? { id: store.id, name: store.name, url: store.url } : nil,
        id: product.id,
        name: product.name,
        slug: product.slug,
        description: product.description,
        sku: product.sku,
        price: product.price&.to_f,
        price_bcv: product.try(:price_bcv)&.to_f,
        bcv_rate: Bcv.last&.value&.to_f,
        currency: product.currency,
        status: product.status,
        available_on: product.available_on,
        discontinue_on: product.discontinue_on,
        meta_title: product.meta_title,
        meta_description: product.meta_description,
        total_on_hand: product.total_on_hand,
        track_inventory: master.track_inventory?,
        taxons: product.taxons.map { |t| { id: t.id, name: t.name, permalink: t.permalink } },
        properties: product.product_properties.includes(:property).map { |pp| { name: pp.property&.presentation, value: pp.value } },
        images: (master.images + product.variant_images).uniq.map { |img|
          { id: img.id, position: img.position, url: img.attachment&.url, alt: img.alt }
        },
        master: variant_as_json(master),
        variants: variants.map { |v| variant_as_json(v) }
      }
    end

    def variant_as_json(variant)
      {
        id: variant.id,
        sku: variant.sku,
        name: variant.descriptive_name,
        options_text: variant.options_text,
        option_values: variant.option_values.sort_by { |ov| ov.option_type&.position.to_i }.map { |ov|
          { id: ov.id, name: ov.name, presentation: ov.presentation, option_type: ov.option_type&.presentation }
        },
        price: variant.price&.to_f,
        prices: variant.prices.map { |p| { currency: p.currency, amount: p.amount&.to_f } },
        weight: variant.weight&.to_f,
        height: variant.height&.to_f,
        width: variant.width&.to_f,
        depth: variant.depth&.to_f,
        is_master: variant.is_master?,
        track_inventory: variant.track_inventory?,
        total_on_hand: variant.total_on_hand,
        stock: variant.stock_items.includes(:stock_location).sort_by { |si| si.stock_location&.name.to_s }.map { |si|
          {
            stock_location_id: si.stock_location_id,
            stock_location_name: si.stock_location&.name,
            count_on_hand: si.count_on_hand,
            backorderable: si.backorderable
          }
        }
      }
    end
  end
end
