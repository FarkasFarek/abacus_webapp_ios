import Foundation
import Network
import SwiftUI

class LocalWebServer: ObservableObject {
    static let shared = LocalWebServer()

    @Published var isRunning = false
    @Published var serverURL = ""
    @Published var accessToken = ""
    @Published var showTokenPopup = false

    private var listener: NWListener?
    private var activeConnections: [NWConnection] = []
    private let port: UInt16 = 8080

    func start() {
        accessToken = generateToken()
        serverURL = "http://\(getLocalIP()):\(port)"
        let params = NWParameters.tcp
        listener = try? NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isRunning = true
                    self?.showTokenPopup = true
                case .failed, .cancelled:
                    self?.isRunning = false
                default: break
                }
            }
        }
        listener?.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        activeConnections.forEach { $0.cancel() }
        activeConnections.removeAll()
        DispatchQueue.main.async {
            self.isRunning = false
            self.showTokenPopup = false
            self.accessToken = ""
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        activeConnections.append(connection)
        receiveRequest(from: connection)
    }

    private func receiveRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] receivedData, _, _, _ in
            guard let self = self, let receivedData = receivedData, !receivedData.isEmpty else {
                connection.cancel()
                return
            }
            let request = NSString( data: receivedData, encoding: NSUTF8StringEncoding) as String? ?? ""
            self.processRequest(request, connection: connection)
        }
    }

    private func processRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        let firstLine = lines.first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        let path = parts.count > 1 ? parts[1] : "/"
        let hasValidToken = path.contains("token=\(accessToken)")
        let cleanPath = path.components(separatedBy: "?").first ?? "/"

        var responseBody = ""
        var contentType = "text/html; charset=utf-8"
        var statusCode = "200 OK"

        if cleanPath == "/api/inventory" && hasValidToken {
            responseBody = generateInventoryJSON()
            contentType = "application/json; charset=utf-8"
        } else if cleanPath == "/" && hasValidToken {
            responseBody = generateHTMLPage()
        } else if cleanPath == "/" && !hasValidToken {
            responseBody = generateLoginPage()
        } else if cleanPath == "/auth" {
            let token = extractTokenFromQuery(path)
            if token == accessToken {
                responseBody = generateHTMLPage()
            } else {
                statusCode = "401 Unauthorized"
                responseBody = generateErrorPage("Ervénytelen token!")
            }
        } else {
            statusCode = "404 Not Found"
            responseBody = generateErrorPage("Az oldal nem talalhato")
        }

        let response = buildHTTPResponse(statusCode: statusCode, contentType: contentType, body: responseBody)
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func extractTokenFromQuery(_ path: String) -> String {
        guard let query = path.components(separatedBy: "?").last else { return "" }
        for param in query.components(separatedBy: "&") {
            let kv = param.components(separatedBy: "=")
            if kv.first == "token" { return kv.last ?? "" }
        }
        return ""
    }

    private func buildHTTPResponse(statusCode: String, contentType: String, body: String) -> String {
        let len = body.data(using: .utf8)?.count ?? 0
        return "HTTP/1.1 \(statusCode)\r\nContent-Type: \(contentType)\r\nContent-Length: \(len)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)"
    }

    private func generateInventoryJSON() -> String {
        let products = InventoryService.shared.fetchProducts()
        var items: [[String: Any]] = []
        for p in products {
            items.append([
                "id": p.id?.uuidString ?? "",
                "name": p.name ?? "",
                "sku": p.sku ?? "",
                "category": p.category ?? "",
                "currentStock": p.currentStock,
                "unit": p.unit ?? "",
                "minStock": p.minStock,
                "price": p.price,
                "location": p.location ?? "",
                "status": p.stockStatus.label,
                "isLowStock": p.isLowStock,
                "isOutOfStock": p.isOutOfStock
            ])
        }
        let payload: [String: Any] = [
            "products": items,
            "count": items.count,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted) else { return "{}" }
        return NSString( data: jsonData, encoding: NSUTF8StringEncoding) as String? ?? "{}"
    }

    private func generateLoginPage() -> String {
        return """
        <!DOCTYPE html>
        <html lang="hu">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Leltar - Belepes</title>
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body { font-family: -apple-system, sans-serif; background: #1a1a2e;
                       min-height: 100vh; display: flex; align-items: center; justify-content: center; }
                .card { background: white; border-radius: 16px; padding: 40px;
                        max-width: 400px; width: 90%; box-shadow: 0 20px 60px rgba(0,0,0,0.3); }
                h1 { font-size: 24px; margin-bottom: 8px; color: #1a1a2e; }
                p { color: #666; margin-bottom: 24px; font-size: 14px; }
                input { width: 100%; padding: 14px; border: 2px solid #e0e0e0;
                        border-radius: 10px; font-size: 18px; letter-spacing: 4px;
                        text-align: center; margin-bottom: 16px; outline: none; }
                input:focus { border-color: #007AFF; }
                button { width: 100%; padding: 14px; background: #007AFF; color: white;
                         border: none; border-radius: 10px; font-size: 16px;
                         font-weight: 600; cursor: pointer; }
                button:hover { background: #0056CC; }
                .icon { font-size: 48px; text-align: center; margin-bottom: 16px; }
            </style>
        </head>
        <body>
            <div class="card">
                <div class="icon">&#128230;</div>
                <h1>Leltar web nezet</h1>
                <p>Add meg a tokent amelyet az alkalmazasban latsz:</p>
                <form action="/auth" method="get">
                    <input type="text" name="token" placeholder="TOKEN" maxlength="8" autocomplete="off" autofocus>
                    <button type="submit">Belepes</button>
                </form>
            </div>
        </body>
        </html>
        """
    }

    private func generateHTMLPage() -> String {
        let products = InventoryService.shared.fetchProducts()
        let stats = InventoryService.shared.dashboardStats()
        let lowStockColor = stats.lowStockCount > 0 ? "#FF9500" : "#34C759"
        var rows = ""
        for p in products {
            let sc = p.isOutOfStock ? "#FF3B30" : p.isLowStock ? "#FF9500" : "#34C759"
            let name = p.name ?? ""
            let sku = p.sku ?? ""
            let cat = p.category ?? "-"
            let stock = fmtQ(p.currentStock)
            let unit = p.unit ?? ""
            let minS = fmtQ(p.minStock)
            let statusLabel = p.stockStatus.label
            let loc = p.location ?? "-"
            rows += "<tr>"
            rows += "<td><strong>" + name + "</strong></td>"
            rows += "<td style='color:#666'>" + sku + "</td>"
            rows += "<td style='color:#666'>" + cat + "</td>"
            rows += "<td style='font-weight:700;color:" + sc + "'>" + stock + " " + unit + "</td>"
            rows += "<td>" + minS + "</td>"
            rows += "<td><span style='background:" + sc + "22;color:" + sc + ";padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600'>" + statusLabel + "</span></td>"
            rows += "<td style='color:#666'>" + loc + "</td>"
            rows += "</tr>"
        }
        let dateStr = Date().formatted(date: .abbreviated, time: .shortened)
        let total = String(stats.totalProducts)
        let lowCount = String(stats.lowStockCount)
        let totalVal = fmtV(stats.totalValue)
        let todayTx = String(stats.todayTransactions)
        let html = """
        <!DOCTYPE html>
        <html lang="hu">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Leltar attekintes</title>
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body { font-family: -apple-system, sans-serif; background: #f2f2f7; color: #1c1c1e; }
                header { background: #007AFF; color: white; padding: 20px 32px;
                         display: flex; justify-content: space-between; align-items: center; }
                header h1 { font-size: 22px; }
                .stats { display: flex; gap: 16px; padding: 24px 32px; flex-wrap: wrap; }
                .stat { background: white; border-radius: 12px; padding: 20px 24px;
                        flex: 1; min-width: 140px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
                .stat .val { font-size: 28px; font-weight: 700; }
                .stat .lbl { font-size: 13px; color: #666; margin-top: 4px; }
                .table-wrap { padding: 0 32px 32px; overflow-x: auto; }
                table { width: 100%; border-collapse: collapse; background: white;
                        border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
                th { background: #f2f2f7; padding: 12px 16px; text-align: left;
                     font-size: 12px; text-transform: uppercase; color: #666; }
                td { padding: 14px 16px; border-top: 1px solid #f0f0f0; font-size: 14px; }
                tr:hover td { background: #f9f9f9; }
                .refresh { color: white; background: rgba(255,255,255,0.2);
                           border: none; padding: 8px 16px; border-radius: 8px; cursor: pointer; }
            </style>
            <script>setTimeout(() => location.reload(), 30000);</script>
        </head>
        <body>
            <header>
                <h1>&#128230; Leltar attekintes</h1>
                <div>
                    <span>Frissitve: 
        """
        let html2 = dateStr + "</span><button class='refresh' onclick='location.reload()'>Frissites</button></div></header>"
        let html3 = """
            <div class="stats">
                <div class="stat"><div class="val" style="color:#007AFF">
        """
        let html4 = total + "</div><div class='lbl'>Termekek szama</div></div>"
            + "<div class='stat'><div class='val' style='color:" + lowStockColor + "'>" + lowCount + "</div><div class='lbl'>Alacsony keszlet</div></div>"
            + "<div class='stat'><div class='val' style='color:#5856D6'>" + totalVal + " Ft</div><div class='lbl'>Keszlet erteke</div></div>"
            + "<div class='stat'><div class='val' style='color:#30B0C7'>" + todayTx + "</div><div class='lbl'>Mai mozgasok</div></div>"
            + "</div><div class='table-wrap'><table><thead><tr>"
            + "<th>Termek neve</th><th>SKU</th><th>Kategoria</th>"
            + "<th>Keszlet</th><th>Min. szint</th><th>Allapot</th><th>Helyszin</th>"
            + "</tr></thead><tbody>" + rows + "</tbody></table></div></body></html>"
        return html + html2 + html3 + html4
    }

    private func generateErrorPage(_ msg: String) -> String {
        return "<html><body style='font-family:sans-serif;text-align:center;padding:60px'><h2>" + msg + "</h2><br><a href='/'>Vissza</a></body></html>"
    }

    private func generateToken() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    func getLocalIP() -> String {
        var address = "localhost"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return address }
        var ptr = ifaddr
        while let addr = ptr {
            let interface = addr.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr,
                                socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
            ptr = addr.pointee.ifa_next
        }
        freeifaddrs(ifaddr)
        return address
    }
}

private func fmtQ(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v)
}
private func fmtV(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: v)) ?? "0"
}
