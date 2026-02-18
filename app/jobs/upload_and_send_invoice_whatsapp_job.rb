require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'stringio'

class UploadAndSendInvoiceWhatsappJob < ApplicationJob
  queue_as :default

  def perform(order_id, image_data_base64, phone, is_group: false)
    order = Spree::Order.find(order_id)
    
    # Remover el prefijo data:image/png;base64, si existe
    base64_data = image_data_base64.gsub(/^data:image\/\w+;base64,/, '')
    
    # Decodificar base64
    decoded_data = Base64.decode64(base64_data)
    
    # Generar nombre único para el archivo
    filename = "invoice_#{order.number}_#{Time.current.to_i}.png"
    
    # Guardar en ActiveStorage asociado al Order
    order.invoice_image.attach(
      io: StringIO.new(decoded_data),
      filename: filename,
      content_type: 'image/png'
    )
    
    Rails.logger.info "Invoice image saved to Order ##{order.number}"
    
    # Verificar que la imagen esté adjunta
    unless order.invoice_image.attached?
      Rails.logger.error "Failed to attach invoice image to Order ##{order.number}"
      return
    end

    # Obtener URL pública directa del servicio de almacenamiento (S3)
    # Usar URL firmada que expira en 1 hora y es accesible públicamente
    image_url = order.invoice_image.url(expires_in: 1.hour, disposition: 'inline')
    
    # Preparar mensaje según el destino
    if is_group
      # Mensaje para el grupo interno
      customer_name = order.ship_address&.full_name || order.bill_address&.full_name || "Cliente"
      message = "🆕 NUEVO PEDIDO - ORDEN #{order.number} - #{customer_name.upcase}"
    else
      # Mensaje para el cliente
      message = "📄 Nota de entrega de tu pedido\n\nOrden: #{order.number}\n\nPor favor leer esta imagen, leer cada artículo, tallas, modelos y los datos de la dirección de envío. Así es como se procesará y enviará tu pedido, como lo descrito en esta imagen y no daremos garantía por lo conversado en el chat, solamente por lo confirmado en esta imagen.\n\nUna vez confirmada esta imagen, no se podrá modificar el pedido.\n\n¿Confirmas tu pedido y envío de pedido con esta imagen?\n\nLa mercancía no tiene cambio ni devolución.\n\nGracias por tu compra en Tarjeta Roja!"
    end
    
    # Enviar mensaje con imagen usando la nueva API de BuilderBot
    response = send_to_builderbot(phone, message, image_url)
    
    if response[:success]
      Rails.logger.info "Invoice uploaded and sent successfully to #{phone} for Order ##{order.number}"
    else
      Rails.logger.error "Error sending invoice to #{phone} for Order ##{order.number}: #{response[:error]}"
      raise "Error al enviar factura: #{response[:error]}"
    end
  end

  private

  def send_to_builderbot(phone, message, media_url = nil)
    begin
      # Configuración de la API de BuilderBot
      builder_bot_url = ENV['BUILDERBOT_URL'] || 'https://app.builderbot.cloud/api/v2/08efa04b-4bca-481a-9c77-03a74047c18a/messages'
      builder_bot_api_key = ENV['BUILDERBOT_API_KEY'] || 'bb-ebaf2518-3b68-4eff-b052-4ff061b01c7d'
      
      uri = URI.parse(builder_bot_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.read_timeout = 30
      http.open_timeout = 10
      
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['x-api-builderbot'] = builder_bot_api_key
      
      # Construir payload según la nueva API
      payload = {
        number: phone,
        checkIfExists: false
      }
      
      # Construir el objeto messages
      messages_hash = {
        content: message
      }
      
      # Agregar mediaUrl si se proporciona
      if media_url.present?
        messages_hash[:mediaUrl] = media_url
      end
      
      payload[:messages] = messages_hash
      
      request.body = payload.to_json
      
      Rails.logger.info "Sending to BuilderBot: #{payload.to_json}"
      
      response = http.request(request)
      
      Rails.logger.info "BuilderBot response: #{response.code} - #{response.body}"
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        { success: true, response: response.body }
      else
        { success: false, error: "HTTP #{response.code}: #{response.body}" }
      end
    rescue => e
      Rails.logger.error "BuilderBot API error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end
end

