require 'net/http'
require 'json'

namespace :stock do
  desc "Sincronizar json_stock_url con productos de otra tienda por slug"
  task :sync_urls, [:remote_url] => :environment do |_t, args|
    remote_url = args[:remote_url] || ENV['REMOTE_STORE_URL']

    abort "Uso: rake \"stock:sync_urls[http://host:puerto]\" o define REMOTE_STORE_URL" if remote_url.blank?

    remote_url = remote_url.chomp('/')
    slugs_endpoint = "#{remote_url}/products/slugs.json"

    puts "Consultando #{slugs_endpoint} ..."

    uri = URI(slugs_endpoint)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      abort "Error HTTP #{response.code} al consultar #{slugs_endpoint}"
    end

    data = JSON.parse(response.body)
    remote_products = data['products']
    remote_store = data['store'] || remote_url

    puts "Tienda remota: #{remote_store}"
    puts "Productos remotos encontrados: #{remote_products.size}"

    remote_map = remote_products.each_with_object({}) { |p, h| h[p['slug']] = p['url'] }

    store = Spree::Store.default
    local_products = store.products.to_a

    updated = 0
    skipped = 0
    no_match = 0

    local_products.each do |product|
      remote_json_url = remote_map[product.slug]

      if remote_json_url.nil?
        no_match += 1
        next
      end

      if product.json_stock_url == remote_json_url
        skipped += 1
        next
      end

      product.update_column(:json_stock_url, remote_json_url)
      updated += 1
      puts "  [OK] #{product.slug} -> #{remote_json_url}"
    end

    puts ""
    puts "=== Resultado ==="
    puts "Actualizados: #{updated}"
    puts "Ya correctos: #{skipped}"
    puts "Sin coincidencia: #{no_match}"
    puts "Total local: #{local_products.size}"
  end
end
