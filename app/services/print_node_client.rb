# frozen_string_literal: true

# Cliente para PrintNode API. Envía trabajos de impresión (ESC/POS en base64)
# a impresoras conectadas vía el cliente PrintNode (funciona desde la nube).
# Credentials: printnode_api_key; opcional printnode_printer_id.
class PrintNodeClient
  BASE_URL = "https://api.printnode.com"
  class Error < StandardError; end
  class NotConfiguredError < Error; end

  def initialize(api_key: nil)
    @api_key = api_key.presence || credentials_api_key
    raise NotConfiguredError, "PrintNode: configura printnode_api_key en credentials" if @api_key.blank?
  end

  def printers
    r = get("/printers")
    return [] unless r.is_a?(Array)
    r
  end

  def default_printer_id
    id = Rails.application.credentials.dig(:printnode_printer_id)
    return id if id.present?
    first = printers.first
    first.is_a?(Hash) && (first["id"] || first[:id])&.to_i
  end

  # Crea un print job con contenido raw (ESC/POS) en base64.
  # printer_id: opcional; si no se pasa, usa el de credentials o el primero disponible.
  def create_print_job(content_base64:, printer_id: nil, title: "Ticket Tarjeta Roja")
    pid = printer_id.presence || default_printer_id
    raise NotConfiguredError, "PrintNode: no hay impresora (configura printnode_printer_id o conecta una en el cliente)" if pid.blank?

    body = {
      printerId: pid.to_i,
      contentType: "raw_base64",
      content: content_base64,
      title: title.to_s
    }
    r = post("/printjobs", body)
    r
  end

  def self.configured?
    key = Rails.application.credentials.dig(:printnode_api_key).to_s
    key.present?
  end

  private

  def credentials_api_key
    Rails.application.credentials.dig(:printnode_api_key).to_s.presence
  end

  def get(path)
    uri = URI.join(BASE_URL, path)
    req = Net::HTTP::Get.new(uri)
    req.basic_auth(@api_key, "")
    req["Content-Type"] = "application/json"
    resp = do_request(uri, req)
    parse_json(resp.body)
  end

  def post(path, body)
    uri = URI.join(BASE_URL, path)
    req = Net::HTTP::Post.new(uri)
    req.basic_auth(@api_key, "")
    req["Content-Type"] = "application/json"
    req.body = body.to_json
    resp = do_request(uri, req)
    parse_json(resp.body)
  end

  def do_request(uri, req)
    use_ssl = uri.scheme == "https"
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = use_ssl
    http.open_timeout = 10
    http.read_timeout = 15
    if use_ssl
      # Si falla "certificate verify failed" (proxy corporativo, CA desactualizados):
      # en credentials pon printnode_verify_ssl: false o ENV PRINTNODE_VERIFY_SSL=0
      if ssl_verify_disabled?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
    end
    resp = http.request(req)
    raise Error, "PrintNode API error: #{resp.code} #{resp.message}" unless resp.is_a?(Net::HTTPSuccess)
    resp
  end

  # true = no verificar SSL (solo si lo activas por proxy/CA rotos)
  def ssl_verify_disabled?
    v = Rails.application.credentials.dig(:printnode_verify_ssl)
    v = ENV["PRINTNODE_VERIFY_SSL"] if v.nil?
    [ false, "false", "0", 0 ].include?(v)
  end

  def parse_json(str)
    return nil if str.blank?
    JSON.parse(str)
  rescue JSON::ParserError
    nil
  end
end
