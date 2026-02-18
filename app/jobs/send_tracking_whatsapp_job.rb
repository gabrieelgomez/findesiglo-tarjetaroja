require 'net/http'
require 'uri'
require 'json'

class SendTrackingWhatsappJob < ApplicationJob
  queue_as :default

  def perform(order_id, phone)
    order = Spree::Order.find(order_id)
    
    # Verificar que la imagen esté adjunta
    unless order.tracking_image.attached?
      Rails.logger.error "Order ##{order.number} does not have tracking image attached"
      return
    end

    # Obtener URL pública directa del servicio de almacenamiento
    image_url = order.tracking_image.url(expires_in: 1.hour, disposition: 'inline')
    
    # Preparar mensaje
    message = "Tu orden ##{order.number} ya ha sido enviada, esta es la guia de tu pedido, por favor leer y revisar esta imagen del envio"
    
    # Enviar mensaje con imagen usando la API de BuilderBot
    response = send_to_builderbot(phone, message, image_url)
    
    if response[:success]
      Rails.logger.info "Tracking image sent successfully to #{phone} for Order ##{order.number}"
    else
      Rails.logger.error "Error sending tracking image to #{phone} for Order ##{order.number}: #{response[:error]}"
      raise "Error al enviar imagen de tracking: #{response[:error]}"
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

