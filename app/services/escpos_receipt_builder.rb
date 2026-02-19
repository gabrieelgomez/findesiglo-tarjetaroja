# frozen_string_literal: true

# Genera comandos ESC/POS para impresoras térmicas (receipt).
# Ancho típico: 48 caracteres para papel 80mm.
# Todo el texto se normaliza a ASCII (sin acentos) para evitar caracteres mal impresos.
class EscposReceiptBuilder
  WIDTH = 48

  # Reemplazo de acentos y caracteres especiales a ASCII para impresoras que no los soportan bien
  ASCII_REPLACE = {
    "á" => "a", "à" => "a", "ä" => "a", "â" => "a", "ã" => "a", "Á" => "A", "À" => "A", "Ä" => "A", "Â" => "A", "Ã" => "A",
    "é" => "e", "è" => "e", "ë" => "e", "ê" => "e", "É" => "E", "È" => "E", "Ë" => "E", "Ê" => "E",
    "í" => "i", "ì" => "i", "ï" => "i", "î" => "i", "Í" => "I", "Ì" => "I", "Ï" => "I", "Î" => "I",
    "ó" => "o", "ò" => "o", "ö" => "o", "ô" => "o", "õ" => "o", "Ó" => "O", "Ò" => "O", "Ö" => "O", "Ô" => "O", "Õ" => "O",
    "ú" => "u", "ù" => "u", "ü" => "u", "û" => "u", "Ú" => "U", "Ù" => "U", "Ü" => "U", "Û" => "U",
    "ñ" => "n", "Ñ" => "N", "ç" => "c", "Ç" => "C", "º" => "o", "ª" => "a", "¿" => "?", "¡" => "!"
  }.freeze

  # Comandos ESC/POS (bytes)
  ESC = "\x1B"
  GS = "\x1D"
  INIT = "#{ESC}@"
  ALIGN_LEFT = "#{ESC}a\x00"
  ALIGN_CENTER = "#{ESC}a\x01"
  ALIGN_RIGHT = "#{ESC}a\x02"
  LF = "\n"
  BOLD_ON = "#{ESC}E\x01"
  BOLD_OFF = "#{ESC}E\x00"
  DOUBLE_HEIGHT_WIDTH = "#{GS}!\x11"
  NORMAL_SIZE = "#{GS}!\x00"
  PARTIAL_CUT = "#{GS}V\x01"
  FULL_CUT = "#{GS}V\x00"
  FEED = "#{ESC}d"

  def initialize(address:, order: nil)
    @address = address
    @order = order
    @buf = String.new
    @buf.force_encoding(Encoding::BINARY)
  end

  def build
    @buf << INIT
    header
    recipient_section
    address_section
    comments_section
    line_items_section if @order&.line_items&.any?
    # agency_section
    footer
    blank_lines(4)   # espacio en blanco antes del corte
    @buf << PARTIAL_CUT
    @buf << (FEED + "\x06") # feed 6 líneas antes del corte (más margen final)
    @buf
  end

  def self.build_receipt(address:, order: nil)
    new(address: address, order: order).build
  end

  private

  def line(text, align: :left)
    cmd = align == :center ? ALIGN_CENTER : (align == :right ? ALIGN_RIGHT : ALIGN_LEFT)
    @buf << cmd
    @buf << wrap(ascii_only(text)).join(LF)
    @buf << LF
  end

  def line_large(text, align: :center)
    @buf << (align == :center ? ALIGN_CENTER : ALIGN_LEFT)
    @buf << DOUBLE_HEIGHT_WIDTH
    @buf << wrap(ascii_only(text), width: (WIDTH / 2)).join(LF)
    @buf << LF
    @buf << NORMAL_SIZE
  end

  def separator
    @buf << ALIGN_LEFT
    @buf << ("-" * 32) << LF
  end

  def blank_lines(n = 1)
    @buf << (LF * n)
  end

  # Convierte acentos y caracteres especiales a ASCII para que la impresora no los muestre mal
  def ascii_only(str)
    return "" if str.blank?
    s = str.to_s
    ASCII_REPLACE.each { |from, to| s = s.gsub(from, to) }
    # Cualquier otro carácter no ASCII se reemplaza por espacio
    s.encode("ASCII", invalid: :replace, undef: :replace, replace: " ")
  end

  def wrap(str, width: WIDTH)
    return [""] if str.blank?
    s = str.to_s
    lines = []
    while s.length > width
      lines << s[0, width]
      s = s[width..] || ""
    end
    lines << s if s.present?
    lines
  end

  def header
    line_large("TARJETA ROJA", align: :center)
    line(@address.agency.present? ? @address.agency.upcase : "--", align: :center)
    @buf << LF
  end

  def recipient_section
    line(@address.full_name.present? ? @address.full_name : "N/A", align: :left)
    line(@address.identifier.present? ? @address.identifier : "N/A", align: :left)
    line(@address.phone.present? ? @address.phone : "N/A", align: :left)
    separator
  end

  def address_section
    address_text = @address.address1.to_s.presence || "N/A"
    line("DIRECCION ENTREGA: #{address_text}", align: :left)
    line("CIUDAD: #{@address.city.present? ? @address.city.upcase : 'N/A'}", align: :left)
    separator
  end

  def comments_section
    comments = @order&.special_instructions.present? ? @order.special_instructions : "N/A"
    line("COMENTARIO: #{comments}", align: :left)
    separator
  end

  def line_items_section
    line("ARTICULOS COMPRADOS", align: :left)
    total_qty = @order.line_items.sum(&:quantity)
    line("Total: #{total_qty} articulos")
    separator
    @order.line_items.each_with_index do |li, idx|
      blank_lines(1) if idx > 0 # espacio entre cada artículo
      line(li.name.to_s.upcase)
      line(li.options_text.to_s.upcase) if li.options_text.present?
      qty_text = li.quantity >= 2 ? "Cantidad: #{li.quantity} ****" : "Cantidad: #{li.quantity}"
      line(qty_text)
    end
    separator
  end

  def agency_section
    line("AGENCIA: #{@address.agency.present? ? @address.agency.upcase : 'N/A'}", align: :left)
    line("ESTADO: #{@address.state_text.present? ? @address.state_text.upcase : 'N/A'}", align: :left)
    separator
  end

  def footer
    @buf << ALIGN_LEFT
    if @order
      order_dt = @order.created_at
      @buf << ascii_only("Pedido: #{format_datetime(order_dt)}") << LF
      @buf << ascii_only("Orden: #{@order.number}") << LF
    end
    @buf << ascii_only("Generado: #{format_datetime(Time.current)}") << LF
  end

  def format_datetime(dt)
    dt.strftime("%d/%m/%Y %H:%M")
  end
end
