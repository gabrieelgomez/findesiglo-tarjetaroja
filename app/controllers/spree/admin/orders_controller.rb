module Spree
  module Admin
    class OrdersController < Spree::Admin::BaseController
      include Spree::Admin::OrderConcern
      include Spree::Admin::OrdersFiltersHelper
      include Spree::Admin::OrderBreadcrumbConcern

      before_action :initialize_order_events
      before_action :load_order, only: %i[show edit cancel resend destroy mark_as_completed upload_tracking_image remove_tracking_image send_tracking_whatsapp update_special_instructions]
      before_action :load_order_items, only: [:edit, :show]
      before_action :load_user, only: [:index]

      helper_method :model_class, :object_url

      # POST /admin/orders
      def create
        @order = Spree::Order.create(created_by: try_spree_current_user, store: current_store)

        redirect_to spree.edit_admin_order_path(@order)
      end

      # GET /admin/orders/:id
      def show
        # Asegurar que @order esté cargado
        load_order unless @order
        
        respond_to do |format|
          format.pdf do
            raise ActiveRecord::RecordNotFound, "Order not found" if @order.nil?
            pdf = generate_order_pdf
            disposition = params[:disposition] == 'attachment' ? 'attachment' : 'inline'
            send_data pdf, filename: "#{@order.number}_invoice.pdf", 
                      type: 'application/pdf', disposition: disposition
          end
          format.html { redirect_to spree.edit_admin_order_path(@order) }
        end
      end

      # GET /admin/orders/:id/edit
      def edit
        unless @order.completed?
          add_breadcrumb Spree.t(:draft_orders), :admin_checkouts_path
        end

        add_breadcrumb @order.number, spree.edit_admin_order_path(@order)
      end

      # GET /admin/orders
      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'completed_at desc'

        load_orders
      end

      # PUT /admin/orders/:id/cancel
      def cancel
        @order.canceled_by(try_spree_current_user)
        flash[:success] = Spree.t(:order_canceled)
        redirect_back fallback_location: spree.edit_admin_order_url(@order)
      end

      # POST /admin/orders/:id/resend
      def resend
        @order.deliver_order_confirmation_email
        if @order.errors.any?
          flash[:error] = @order.errors.full_messages.join(', ')
        else
          flash[:success] = Spree.t(:order_email_resent)
        end

        redirect_back fallback_location: spree.edit_admin_order_url(@order)
      end

      # POST /admin/orders/:id/mark_as_completed
      def mark_as_completed
        completed_at = Time.current
        completed_by_user = try_spree_current_user

        # Completar la orden guardando quién y cuándo
        @order.update(
          state: 'complete',
          shipment_state: 'shipped',
          payment_state: 'paid',
          completed_by_id: completed_by_user&.id
        )

        flash[:success] = Spree.t(:order_marked_as_completed)
        redirect_to spree.edit_admin_order_path(@order)
      end

      # POST /admin/orders/:id/upload_tracking_image
      def upload_tracking_image
        if params[:tracking_image].present?
          # Procesar la imagen con variant antes de adjuntar para reducir el tamaño
          image_file = params[:tracking_image]
          
          # Crear blob temporal para procesar la imagen
          temp_blob = ActiveStorage::Blob.create_and_upload!(
            io: image_file,
            filename: image_file.original_filename,
            content_type: image_file.content_type
          )
          
          # Procesar con variant para redimensionar (máximo 600x600 manteniendo proporción)
          variant = temp_blob.variant(resize_to_limit: [600, 600])
          processed_variant = variant.processed
          
          # Descargar la imagen procesada desde el variant
          processed_image_data = processed_variant.download
          
          # Eliminar el blob temporal
          temp_blob.purge
          
          # Adjuntar la versión procesada (más pequeña)
          @order.tracking_image.attach(
            io: StringIO.new(processed_image_data),
            filename: image_file.original_filename,
            content_type: image_file.content_type
          )
          
          flash[:success] = "Imagen de tracking subida y optimizada correctamente"
        else
          flash[:error] = "Por favor selecciona una imagen"
        end
        redirect_to spree.edit_admin_order_path(@order)
      end

      # DELETE /admin/orders/:id/remove_tracking_image
      def remove_tracking_image
        @order.tracking_image.purge if @order.tracking_image.attached?
        flash[:success] = "Imagen de tracking eliminada correctamente"
        redirect_to spree.edit_admin_order_path(@order)
      end

      # POST /admin/orders/:id/send_tracking_whatsapp
      def send_tracking_whatsapp
        # Verificar que la imagen esté adjunta
        unless @order.tracking_image.attached?
          flash[:error] = "La orden no tiene imagen de tracking. Por favor, sube una imagen primero."
          redirect_to spree.edit_admin_order_path(@order)
          return
        end

        # Obtener teléfono del cliente
        phone = @order.ship_address&.phone || @order.bill_address&.phone
        
        if phone.blank?
          flash[:error] = "No se encontró número de teléfono en la dirección de envío o facturación del cliente."
          redirect_to spree.edit_admin_order_path(@order)
          return
        end

        # Formatear número de teléfono
        formatted_phone = phone.gsub(/\D/, '')
        
        if formatted_phone.length < 10
          flash[:error] = "El número de teléfono debe tener al menos 10 dígitos"
          redirect_to spree.edit_admin_order_path(@order)
          return
        end

        # Enviar en segundo plano con ActiveJob
        SendTrackingWhatsappJob.perform_later(@order.id, formatted_phone)
        
        flash[:success] = "El envío de tracking por WhatsApp se está procesando en segundo plano"
        redirect_to spree.edit_admin_order_path(@order)
      end

      # PATCH /admin/orders/:id/update_special_instructions
      def update_special_instructions
        if @order.update(special_instructions: params[:order][:special_instructions])
          flash[:success] = Spree.t(:successfully_updated, resource: I18n.t('activerecord.attributes.spree/order.special_instructions'))
        else
          flash[:error] = @order.errors.full_messages.join(', ')
        end
        redirect_to spree.edit_admin_order_path(@order)
      end

      # DELETE /admin/orders/:id
      def destroy
        @order.destroy
        flash[:success] = flash_message_for(@order, :successfully_removed)

        if @order.completed?
          redirect_to spree.admin_orders_path
        else
          redirect_to spree.admin_checkouts_path
        end
      end

      private

      def scope
        base_scope = current_store.orders.accessible_by(current_ability, :index)

        if action_name == 'index'
          base_scope.complete
        else
          base_scope
        end
      end

      def order_params
        params[:created_by_id] = try_spree_current_user.try(:id)
        params.permit(:created_by_id, :user_id, :store_id, :channel, tag_list: [])
      end

      def load_order
        @order = scope.includes(:adjustments).find_by!(number: params[:id])
        authorize! action, @order
      end

      def load_order_items
        @line_items = @order.line_items.includes(variant: [:product, :option_values])
        @shipments = @order.shipments.includes(:inventory_units, :selected_shipping_rate,
                                               shipping_rates: [:shipping_method, :tax_rate]).order(:created_at)
        @payments = @order.payments.includes(:payment_method, :source).order(:created_at)
        @refunds = @order.refunds

        @return_authorizations = @order.return_authorizations.includes(:return_items)
        @customer_returns = @order.customer_returns.distinct
      end

      # Used for extensions which need to provide their own custom event links on the order details view.
      def initialize_order_events
        @order_events = %w{approve cancel resume}
      end

      def model_class
        Spree::Order
      end

      # needed to show the delete button in the content header
      def object_url
        spree.admin_order_path(@order)
      end

      def generate_order_pdf
        require 'prawn'
        require 'prawn/table'
        
        # Validar que @order esté cargado
        raise "Order not found" if @order.nil?
        
        store = current_store
        # Usar A4 con márgenes modernos
        pdf = Prawn::Document.new(page_size: 'A4', margin: [60, 50, 60, 50])
        available_width = 495
        
        # Colores modernos inspirados en Tailwind
        primary_color = "1F2937"      # gray-800
        secondary_color = "6B7280"     # gray-500
        accent_color = "3B82F6"       # blue-500
        bg_light = "F9FAFB"           # gray-50
        border_color = "E5E7EB"       # gray-200
        
        # Calcular valores necesarios antes de crear las tablas
        line_items_count = @order.line_items.count
        adjustments_count = @order.all_adjustments.eligible.count
        
        # Helper para cargar imágenes desde Active Storage (lambda)
        load_image_path = lambda do |attachment|
          return nil unless attachment&.attached?
          
          begin
            if attachment.blob.service_name == 'local'
              image_path = attachment.blob.service.path_for(attachment.blob.key)
              return image_path if File.exist?(image_path)
            else
              temp_file = Tempfile.new(['image', '.png'])
              attachment.download { |chunk| temp_file.write(chunk) }
              temp_file.rewind
              return temp_file.path
            end
          rescue => e
            Rails.logger.error "Error loading image: #{e.message}"
            return nil
          end
          nil
        end
        
        # Header con membrete de la empresa - diseño moderno
        logo_y_position = 780
        logo_size = 80
        
        if store.logo.attached?
          logo_path = load_image_path.call(store.logo)
          if logo_path
            pdf.image logo_path, at: [-50, logo_y_position], width: logo_size
          end
        end
        
        # Información de la empresa - diseño limpio
        pdf.fill_color primary_color
        company_info_y = 750
        
        # Nombre de la empresa
        if store.name.present?
          pdf.text_box store.name, at: [350, company_info_y], size: 20, style: :bold, 
                      align: :right, width: 200, valign: :top
        end
        
        # Información de contacto en columna izquierda
        info_y = company_info_y - 25
        pdf.fill_color secondary_color
        pdf.font_size 9
        
        rif = store.public_metadata&.dig('rif') || store.public_metadata&.dig('RIF') || '[CONFIGURAR RIF]'
        pdf.text_box "RIF: #{rif}", at: [15, info_y], width: 300 if rif.present?
        
        if store.address.present?
          pdf.text_box store.address.to_s, at: [15, info_y - 12], width: 300
        end
        
        if store.contact_phone.present?
          pdf.text_box "Teléfono: #{store.contact_phone}", at: [15, info_y - 24], width: 300
        end
        
        if store.url.present?
          pdf.text_box "Web: #{store.url}", at: [15, info_y - 36], width: 300
        end
        
        pdf.move_down 50
        
        # Título del documento - estilo moderno
        pdf.fill_color accent_color
        pdf.font_size 24
        pdf.text "NOTA DE ENTREGA", align: :right, style: :bold
        pdf.fill_color primary_color
        
        pdf.move_down 25
        
        # Información de la orden - diseño moderno
        pdf.fill_color secondary_color
        pdf.font_size 10
        order_info = []
        order_info << "Orden: #{@order.number}"
        order_info << "Fecha: #{@order.created_at.strftime('%d/%m/%Y')}" if @order.created_at
        pdf.text_box order_info.join(" • "), at: [pdf.bounds.width - 250, pdf.cursor], 
                    width: 250, align: :right
        pdf.fill_color primary_color
        
        pdf.move_down 20
        
        # Datos del cliente - diseño moderno con fondo
        bill_address = @order.bill_address
        if bill_address
          customer_box_y = pdf.cursor + 5
          customer_box_height = 80
          pdf.fill_color bg_light
          pdf.rectangle [0, customer_box_y], available_width, customer_box_height
          pdf.fill
          pdf.stroke_color border_color
          pdf.stroke_rectangle [0, customer_box_y], available_width, customer_box_height
          
          pdf.fill_color primary_color
          pdf.font_size 11
          pdf.text_box "DATOS DEL CLIENTE", at: [10, pdf.cursor + 70], width: available_width - 20, style: :bold
          
          pdf.fill_color secondary_color
          pdf.font_size 9
          customer_info = []
          customer_info << "Cliente: #{bill_address.full_name.titleize}"
          customer_info << "Empresa: #{bill_address.company.titleize}" if bill_address.company.present?
          customer_info << "Cédula / RIF: #{bill_address.dni}" if bill_address.respond_to?(:dni) && bill_address.dni.present?
          customer_info << "Teléfono: #{bill_address.phone}" if bill_address.phone.present?
          customer_info << "Dirección: #{bill_address.address1&.titleize}, #{bill_address.zipcode} #{bill_address.city&.titleize}" if bill_address.address1.present?
          customer_info << "País: #{bill_address.country&.name&.titleize}" if bill_address.country.present?
          
          pdf.text_box customer_info.join("\n"), at: [10, pdf.cursor + 50], 
                      width: available_width - 20, leading: 4
          pdf.fill_color primary_color
        end
        
        pdf.move_down 30
        
        # Items de la orden - diseño moderno con imágenes
        pdf.fill_color primary_color
        pdf.font_size 12
        pdf.text "PRODUCTOS", leading: 2, style: :bold
        pdf.move_down 10
        
        # Crear tabla con imágenes
        line_items_data = []
        # Header con fondo
        header_row = ['', 'Producto', 'SKU', 'Precio', 'Cant.', 'Total']
        line_items_data << header_row
        
        # Preparar datos de items con imágenes
        item_rows = []
        @order.line_items.includes(variant: [:images, :product]).each do |item|
          # Obtener imagen del producto
          image_path = nil
          image_cell = ''
          
          variant_image = item.variant.default_image || item.variant.images.first || item.variant.product.images.first
          if variant_image&.attached?
            image_path = load_image_path.call(variant_image)
          end
          
          # Crear celda con imagen (se agregará después)
          product_name = item.variant.product.name
          product_name += "\n#{item.variant.options_text}" if item.variant.options_text.present?
          
          row_data = {
            image_path: image_path,
            product: product_name,
            sku: item.variant.product.sku || '',
            price: item.single_display_amount.to_s,
            quantity: item.quantity.to_s,
            total: item.display_amount.to_s
          }
          item_rows << row_data
        end
        
        # Construir tabla con imágenes inline
        item_rows.each do |row_data|
          # Crear celda de imagen como texto placeholder (Prawn no soporta imágenes inline en tablas fácilmente)
          # Usaremos un enfoque diferente: dibujar la tabla y luego agregar imágenes
          line_items_data << [
            '', # placeholder para imagen
            row_data[:product],
            row_data[:sku],
            row_data[:price],
            row_data[:quantity],
            row_data[:total]
          ]
        end
        
        # Totales
        line_items_data << [""] * 6
        line_items_data << [nil, nil, nil, nil, "Subtotal", @order.display_item_total.to_s]
        
        @order.all_adjustments.eligible.each do |adjustment|
          line_items_data << [nil, nil, nil, nil, adjustment.label, adjustment.display_amount.to_s]
        end
        
        line_items_data << [nil, nil, nil, nil, "Total", @order.display_total.to_s]
        
        # Anchos de columnas ajustados (imagen: 50, producto: 200, sku: 80, precio: 60, cant: 40, total: 65)
        column_widths = { 0 => 50, 1 => 200, 2 => 80, 3 => 60, 4 => 40, 5 => 65 }
        table_width = column_widths.values.sum # 495
        
        # Guardar posición Y antes de la tabla para agregar imágenes después
        table_start_y = pdf.cursor
        row_height = 50 # Altura de cada fila de producto
        
        pdf.table(line_items_data, width: table_width, column_widths: column_widths) do
          cells.border_width = 0
          cells.padding = [8, 4]
          
          # Header con fondo gris
          row(0).background_color = primary_color
          row(0).text_color = "FFFFFF"
          row(0).font_style = :bold
          row(0).font_size = 9
          row(0).borders = []
          row(0).height = 30
          
          # Filas de productos - estilo alternado
          (1..line_items_count).each do |i|
            row(i).height = row_height
            if i.odd?
              row(i).background_color = bg_light
            end
            row(i).borders = [:bottom]
            row(i).border_color = border_color
            row(i).font_size = 8
            row(i).columns(1).font_style = :bold
            row(i).columns(3..5).align = :right
            row(i).valign = :center
          end
          
          # Filas de totales
          if line_items_data.length > line_items_count + 2
            total_rows_start = line_items_data.length - (adjustments_count + 3)
            row(total_rows_start..-2).borders = []
            row(total_rows_start..-2).background_color = "FFFFFF"
            row(total_rows_start..-2).column(4).font_style = :bold
            row(total_rows_start..-2).column(4).align = :right
            row(total_rows_start..-2).column(5).align = :right
            
            row(-1).borders = [:top]
            row(-1).border_color = primary_color
            row(-1).border_width = 2
            row(-1).background_color = bg_light
            row(-1).column(4).font_style = :bold
            row(-1).column(4).font_size = 10
            row(-1).column(5).font_style = :bold
            row(-1).column(5).font_size = 10
            row(-1).column(4).align = :right
            row(-1).column(5).align = :right
          end
        end
        
        # Agregar imágenes de productos después de dibujar la tabla
        # Calcular posición Y: header (30) + filas de productos
        header_height = 30
        item_rows.each_with_index do |row_data, index|
          if row_data[:image_path] && File.exist?(row_data[:image_path])
            # Calcular posición Y: table_start_y - header_height - (index * row_height) - (row_height / 2) para centrar
            image_y = table_start_y - header_height - (index * row_height) - (row_height / 2) + 20
            begin
              pdf.image row_data[:image_path], at: [5, image_y], width: 40, height: 40, fit: [40, 40]
            rescue => e
              Rails.logger.error "Error drawing product image: #{e.message}"
            end
          end
        end
        
        pdf.move_down 30
        
        # Pagos - diseño moderno
        pdf.fill_color primary_color
        pdf.font_size 12
        pdf.text "PAGOS REALIZADOS", leading: 2, style: :bold
        pdf.move_down 15
        
        payments = @order.payments.where(state: 'completed').order(id: :asc)
        
        if payments.any?
          payments_data = [['Método de pago', 'Fecha', 'Monto']]
          
          payments.each do |payment|
            payments_data << [
              payment.payment_method.name,
              payment.created_at.strftime('%d/%m/%Y'),
              Spree::Money.new(payment.amount, { currency: @order.currency || 'USD' }).to_s
            ]
          end
          
          pdf.table(payments_data, width: 400, column_widths: { 0 => 200, 1 => 100, 2 => 100 }) do
            cells.border_width = 0
            cells.padding = [8, 6]
            
            row(0).background_color = primary_color
            row(0).text_color = "FFFFFF"
            row(0).font_style = :bold
            row(0).font_size = 9
            row(0).borders = []
            row(0).height = 30
            
            (1..payments_data.length - 1).each do |i|
              row(i).height = 35
              if i.odd?
                row(i).background_color = bg_light
              end
              row(i).borders = [:bottom]
              row(i).border_color = border_color
              row(i).font_size = 9
              row(i).columns(2).align = :right
              row(i).valign = :center
            end
          end
        else
          pdf.fill_color secondary_color
          pdf.font_size 9
          pdf.text "No hay pagos registrados", style: :italic
          pdf.fill_color primary_color
        end
        
        pdf.move_down 20
        
        # Resumen de pagos - diseño destacado
        summary_box_y = pdf.cursor + 5
        summary_box_height = 60
        pdf.fill_color bg_light
        pdf.rectangle [0, summary_box_y], 400, summary_box_height
        pdf.fill
        pdf.stroke_color border_color
        pdf.stroke_rectangle [0, summary_box_y], 400, summary_box_height
        
        pdf.fill_color primary_color
        pdf.font_size 10
        
        # TOTAL ABONOS
        pdf.text_box "TOTAL ABONOS", at: [15, summary_box_y + 40], width: 180, style: :bold
        pdf.text_box Spree::Money.new(@order.payment_total, { currency: @order.currency || 'USD' }).to_s, 
                    at: [200, summary_box_y + 40], width: 180, align: :right, style: :bold
        
        # MONTO RESTANTE
        pdf.text_box "MONTO RESTANTE", at: [15, summary_box_y + 15], width: 180, style: :bold
        pdf.fill_color = @order.outstanding_balance > 0 ? "DC2626" : "059669" # rojo si hay pendiente, verde si está pagado
        pdf.text_box Spree::Money.new(@order.outstanding_balance, { currency: @order.currency || 'USD' }).to_s, 
                    at: [200, summary_box_y + 15], width: 180, align: :right, style: :bold
        
        pdf.render
      end
    end
  end
end
