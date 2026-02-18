import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "downloadButton", "printButton"]
  
  connect() {
    console.log('AddressImage controller connected')
    console.log('Container target:', this.hasContainerTarget)
    console.log('Download button target:', this.hasDownloadButtonTarget)
    console.log('Print button target:', this.hasPrintButtonTarget)
    
    // Cargar html2canvas si no está disponible
    this.loadHtml2Canvas()
  }
  
  loadHtml2Canvas() {
    if (typeof html2canvas !== 'undefined') {
      console.log('html2canvas ya está disponible')
      return
    }
    
    const script = document.createElement('script')
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js'
    script.onload = () => {
      console.log('html2canvas loaded successfully')
    }
    script.onerror = () => {
      console.error('Error cargando html2canvas')
    }
    document.head.appendChild(script)
  }
  
  generateImage() {
    console.log('Generando imagen...')
    
    // Esperar un poco para que html2canvas se cargue si es necesario
    if (typeof html2canvas === 'undefined') {
      console.log('Esperando a que html2canvas se cargue...')
      setTimeout(() => this.generateImage(), 500)
      return
    }
    
    const card = this.containerTarget.querySelector('.address-card')
    if (!card) {
      console.error('No se encontró el elemento .address-card')
      return
    }
    
    console.log('Generando canvas...')
    html2canvas(card, {
      backgroundColor: '#ffffff',
      scale: 2, // Mejor calidad
      useCORS: true,
      allowTaint: true,
      width: 400,
      height: card.offsetHeight,
      logging: true // Para debug
    }).then((canvas) => {
      console.log('Canvas generado, creando descarga...')
      // Crear enlace de descarga
      const link = document.createElement('a')
      link.download = `direccion_${Date.now()}.png`
      link.href = canvas.toDataURL('image/png')
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      console.log('Descarga iniciada')
    }).catch((error) => {
      console.error('Error generando imagen:', error)
    })
  }
  
  printImage() {
    console.log('Imprimiendo imagen...')
    
    // Esperar un poco para que html2canvas se cargue si es necesario
    if (typeof html2canvas === 'undefined') {
      console.log('Esperando a que html2canvas se cargue...')
      setTimeout(() => this.printImage(), 500)
      return
    }
    
    const card = this.containerTarget.querySelector('.address-card')
    if (!card) {
      console.error('No se encontró el elemento .address-card')
      return
    }
    
    console.log('Generando canvas para impresión...')
    html2canvas(card, {
      backgroundColor: '#ffffff',
      scale: 2,
      useCORS: true,
      allowTaint: true,
      width: 400,
      height: card.offsetHeight
    }).then((canvas) => {
      console.log('Canvas generado, abriendo ventana de impresión...')
      
      // Crear una nueva ventana para imprimir
      const printWindow = window.open('', '_blank')
      printWindow.document.write(`
        <html>
          <head>
            <title>Dirección - Imprimir</title>
            <style>
              body { margin: 0; padding: 20px; font-family: Arial, sans-serif; }
              .print-container { text-align: center; }
              img { max-width: 100%; height: auto; }
            </style>
          </head>
          <body>
            <div class="print-container">
              <img src="${canvas.toDataURL('image/png')}" alt="Dirección" />
            </div>
          </body>
        </html>
      `)
      printWindow.document.close()
      
      // Esperar a que la imagen se cargue y luego imprimir
      printWindow.onload = () => {
        printWindow.print()
        printWindow.close()
      }
    }).catch((error) => {
      console.error('Error generando imagen para impresión:', error)
    })
  }
  
  showDownloadButton() {
    if (this.hasDownloadButtonTarget) {
      this.downloadButtonTarget.style.display = 'block'
    }
  }
} 