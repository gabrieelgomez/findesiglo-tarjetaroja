module Spree
  module Admin
    class AddressImagesController < Spree::Admin::BaseController
      include ActionView::Helpers::AssetUrlHelper
      require 'base64'
      require 'securerandom'
      require 'stringio'
      require 'net/http'
      require 'uri'
      require 'json'
      def show
        @address = Spree::Address.find(params[:id])
        @order = Spree::Order.find(params[:order_id]) if params[:order_id].present?
        respond_to do |format|
          format.html do
            render layout: false
          end
          format.png do
            # Aquí se generaría la imagen usando un servicio
            # Por ahora solo renderizamos la vista
            render layout: false
          end
        end
      end

      def show_a4
        @address = Spree::Address.find(params[:id])
        @order = Spree::Order.find(params[:order_id]) if params[:order_id].present?
        respond_to do |format|
          format.html do
            render layout: false
          end
        end
      end

      # Ticket en formato ESC/POS para impresora térmica (USB).
      # Devuelve JSON con data en base64 para enviar vía QZ Tray u otro cliente raw.
      def escpos
        @address = Spree::Address.find(params[:id])
        @order = Spree::Order.find(params[:order_id]) if params[:order_id].present?
        raw_bytes = EscposReceiptBuilder.build_receipt(address: @address, order: @order)
        data_base64 = Base64.strict_encode64(raw_bytes)
        render json: { data: data_base64 }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Dirección u orden no encontrada" }, status: :not_found
      end

      # Certificado público para QZ Tray (firma remota desde tutarjetaroja.com).
      def qz_certificate
        pem = QzTraySigningService.certificate_pem
        render plain: pem, content_type: "text/plain"
      rescue QzTraySigningService::NotConfiguredError
        head :service_unavailable
      end

      # Firma el payload toSign de QZ Tray; devuelve firma en base64.
      def qz_sign
        to_sign = params[:request].presence || request.raw_post
        signature = QzTraySigningService.sign(to_sign)
        render json: { signature: signature }
      rescue QzTraySigningService::NotConfiguredError => e
        Rails.logger.warn "QZ Tray signing: #{e.message}"
        render json: { error: "Firma no configurada" }, status: :service_unavailable
      rescue StandardError => e
        Rails.logger.error "QZ Tray sign error: #{e.message}"
        render json: { error: "Error al firmar" }, status: :internal_server_error
      end

      # Envía el ticket ESC/POS a PrintNode (impresora en la nube). Funciona desde tutarjetaroja.com.
      # Params: address_id, order_id; opcional printer_id.
      def print_via_printnode
        @address = Spree::Address.find(params[:address_id])
        @order = Spree::Order.find(params[:order_id]) if params[:order_id].present?
        raw_bytes = EscposReceiptBuilder.build_receipt(address: @address, order: @order)
        content_base64 = Base64.strict_encode64(raw_bytes)
        title = @order ? "Ticket #ORD-#{@order.number}" : "Ticket direccion #{@address.id}"

        client = PrintNodeClient.new
        job = client.create_print_job(
          content_base64: content_base64,
          printer_id: params[:printer_id].presence,
          title: title
        )
        render json: { success: true, job_id: job&.dig("id") || job&.dig(:id), message: "Enviado a la impresora" }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Dirección u orden no encontrada" }, status: :not_found
      rescue PrintNodeClient::NotConfiguredError => e
        render json: { error: e.message }, status: :service_unavailable
      rescue PrintNodeClient::Error => e
        Rails.logger.error "PrintNode: #{e.message}"
        render json: { error: "PrintNode: #{e.message}" }, status: :unprocessable_entity
      end

      def upload_image
        begin
          # Recibir imagen en base64 y order_id
          image_data = params[:image]
          order_id = params[:order_id]
          
          if image_data.blank?
            render json: { error: 'No se proporcionó imagen' }, status: :bad_request
            return
          end
          
          if order_id.blank?
            render json: { error: 'No se proporcionó order_id' }, status: :bad_request
            return
          end
          
          @order = Spree::Order.find(order_id)
          
          # Remover el prefijo data:image/png;base64, si existe
          base64_data = image_data.gsub(/^data:image\/\w+;base64,/, '')
          
          # Decodificar base64
          decoded_data = Base64.decode64(base64_data)
          
          # Generar nombre único para el archivo
          filename = "invoice_#{@order.number}_#{Time.current.to_i}.png"
          
          # Guardar en ActiveStorage asociado al Order
          @order.invoice_image.attach(
            io: StringIO.new(decoded_data),
            filename: filename,
            content_type: 'image/png'
          )
          
          # Generar URL pública usando ActiveStorage
          image_url = nil
          if @order.invoice_image.attached?
            # Obtener URL pública directa del servicio de almacenamiento (S3)
            # Usar URL firmada que expira en 1 hora y es accesible públicamente
            image_url = @order.invoice_image.url(expires_in: 1.hour, disposition: 'inline')
          end
          
          Rails.logger.info "Invoice image saved to Order ##{@order.number}, URL: #{image_url}"
          
          render json: { url: image_url, filename: filename, order_id: @order.id }, status: :ok
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.error "Order not found: #{e.message}"
          render json: { error: "Orden no encontrada" }, status: :not_found
        rescue => e
          Rails.logger.error "Error uploading image: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: "Error al procesar la imagen: #{e.message}" }, status: :internal_server_error
        end
      end
      
      def send_whatsapp_invoice
        begin
          order_id = params[:order_id]
          phone = params[:phone]
          
          if order_id.blank?
            render json: { error: 'No se proporcionó order_id' }, status: :bad_request
            return
          end
          
          if phone.blank?
            render json: { error: 'No se proporcionó número de teléfono' }, status: :bad_request
            return
          end
          
          @order = Spree::Order.find(order_id)
          
          # Verificar que la imagen esté adjunta
          unless @order.invoice_image.attached?
            render json: { error: 'La orden no tiene factura generada. Por favor, genera la imagen primero.' }, status: :unprocessable_entity
            return
          end
          
          # Formatear número de teléfono
          formatted_phone = phone.gsub(/\D/, '')
          
          if formatted_phone.length < 10
            render json: { error: 'El número de teléfono debe tener al menos 10 dígitos' }, status: :bad_request
            return
          end
          
          # Enviar en segundo plano con ActiveJob
          SendInvoiceWhatsappJob.perform_later(@order.id, formatted_phone)
          
          render json: { 
            success: true, 
            message: "El envío de factura por WhatsApp se está procesando en segundo plano",
            order_number: @order.number
          }, status: :ok
          
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.error "Order not found: #{e.message}"
          render json: { error: "Orden no encontrada" }, status: :not_found
        rescue => e
          Rails.logger.error "Error queuing WhatsApp invoice: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: "Error al procesar solicitud: #{e.message}" }, status: :internal_server_error
        end
      end

      def upload_and_send_whatsapp_invoice
        begin
          # Recibir imagen en base64, order_id y phone
          image_data = params[:image]
          order_id = params[:order_id]
          phone = params[:phone]
          
          if image_data.blank?
            render json: { error: 'No se proporcionó imagen' }, status: :bad_request
            return
          end
          
          if order_id.blank?
            render json: { error: 'No se proporcionó order_id' }, status: :bad_request
            return
          end
          
          if phone.blank?
            render json: { error: 'No se proporcionó número de teléfono o ID de grupo' }, status: :bad_request
            return
          end
          
          @order = Spree::Order.find(order_id)
          
          # Verificar si es un ID de grupo (contiene letras) o un número de teléfono
          is_group_id = phone.match?(/[a-zA-Z]/)
          
          if is_group_id
            # Para IDs de grupo, usar el valor tal cual
            formatted_phone = phone
          else
            # Para números de teléfono, formatear y validar
            formatted_phone = phone.gsub(/\D/, '')
            
            if formatted_phone.length < 10
              render json: { error: 'El número de teléfono debe tener al menos 10 dígitos' }, status: :bad_request
              return
            end
          end
          
          # Enviar todo en segundo plano con ActiveJob (subir imagen y enviar por WhatsApp)
          UploadAndSendInvoiceWhatsappJob.perform_later(@order.id, image_data, formatted_phone, is_group: is_group_id)
          
          render json: { 
            success: true, 
            message: "La factura se está subiendo y enviando por WhatsApp en segundo plano",
            order_number: @order.number
          }, status: :ok
          
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.error "Order not found: #{e.message}"
          render json: { error: "Orden no encontrada" }, status: :not_found
        rescue => e
          Rails.logger.error "Error queuing upload and send WhatsApp invoice: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: "Error al procesar solicitud: #{e.message}" }, status: :internal_server_error
        end
      end
      
      private

      def test
        render 'spree/admin/address_images/test', layout: false
      end
    end
  end
end
