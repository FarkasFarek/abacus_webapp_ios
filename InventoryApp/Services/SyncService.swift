import Foundation
import CoreData

private let WORKER_URL = "https://inventory-api.farkascoach.workers.dev"
private let API_SECRET = "Farkas-010499-Falka"

class SyncService {
    static let shared = SyncService()
    private let service = InventoryService.shared
    private let context = PersistenceController.shared.container.viewContext
    private let lastSyncKey = "lastSyncDate"

    var isConfigured: Bool { !WORKER_URL.isEmpty && !API_SECRET.isEmpty }

    // MARK: - Push single product
    func pushProduct(_ product: ProductEntity) {
        guard isConfigured else { return }
        post(path: "/api/products", body: productDict(product))
    }

    // MARK: - Push single transaction
    func pushTransaction(_ tx: TransactionEntity) {
        guard isConfigured else { return }
        post(path: "/api/transactions", body: txDict(tx))
    }

    // MARK: - Full push
    func pushAll(completion: ((Bool) -> Void)? = nil) {
        guard isConfigured else { completion?(false); return }
        let products = service.fetchProducts().map { productDict($0) }
        let transactions = service.fetchTransactions(limit: 100000).map { txDict($0) }
        let body: [String: Any] = ["products": products, "transactions": transactions]
        post(path: "/api/sync/push", body: body) { success in
            DispatchQueue.main.async { completion?(success) }
        }
    }

    // MARK: - Pull
    func pull(completion: ((Bool, Int, Int) -> Void)? = nil) {
        guard isConfigured else { completion?(false, 0, 0); return }
        let since = UserDefaults.standard.string(forKey: lastSyncKey)
        var path = "/api/sync"
        if let since = since { path += "?since=\(since)" }

        get(path: path) { [weak self] data in
            guard let self = self, let data = data else {
                DispatchQueue.main.async { completion?(false, 0, 0) }
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let products = json?["products"] as? [[String: Any]] ?? []
                let transactions = json?["transactions"] as? [[String: Any]] ?? []
                let syncedAt = json?["syncedAt"] as? String
                DispatchQueue.main.async {
                    self.applyProducts(products)
                    self.applyTransactions(transactions)
                    if let s = syncedAt { UserDefaults.standard.set(s, forKey: self.lastSyncKey) }
                    completion?(true, products.count, transactions.count)
                }
            } catch {
                DispatchQueue.main.async { completion?(false, 0, 0) }
            }
        }
    }

    // MARK: - Apply products
    private func applyProducts(_ products: [[String: Any]]) {
        for p in products {
            guard let idStr = p["id"] as? String, let id = UUID(uuidString: idStr) else { continue }
            let deleted = p["deleted"] as? Int ?? 0
            let req = ProductEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            let existing = (try? context.fetch(req))?.first
            if deleted == 1 { if let e = existing { context.delete(e) }; continue }
            let entity = existing ?? ProductEntity(context: context)
            entity.id           = id
            entity.name         = p["name"] as? String ?? ""
            entity.sku          = p["sku"] as? String ?? ""
            entity.barcode      = p["barcode"] as? String ?? ""
            entity.category     = p["category"] as? String ?? ""
            entity.unit         = p["unit"] as? String ?? "db"
            entity.minStock     = p["min_stock"] as? Double ?? 0
            entity.currentStock = p["current_stock"] as? Double ?? 0
            entity.price        = p["price"] as? Double ?? 0
            entity.location     = p["location"] as? String
            entity.note         = p["note"] as? String
            if let ca = p["created_at"] as? String { entity.createdAt = Date.fromISO(ca) }
        }
        PersistenceController.shared.save()
    }

    // MARK: - Apply transactions
    private func applyTransactions(_ txs: [[String: Any]]) {
        for t in txs {
            guard let idStr = t["id"] as? String, let id = UUID(uuidString: idStr) else { continue }
            let req = TransactionEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            if (try? context.fetch(req))?.first != nil { continue }
            let entity = TransactionEntity(context: context)
            entity.id           = id
            entity.productId    = UUID(uuidString: t["product_id"] as? String ?? "")
            entity.productName  = t["product_name"] as? String
            entity.type         = t["type"] as? String
            entity.quantity     = t["quantity"] as? Double ?? 0
            entity.note         = t["note"] as? String
            entity.deliveryNote = t["delivery_note"] as? String
            entity.user         = t["user"] as? String
            entity.stockBefore  = t["stock_before"] as? Double ?? 0
            entity.stockAfter   = t["stock_after"] as? Double ?? 0
            if let ts = t["timestamp"] as? String { entity.timestamp = Date.fromISO(ts) }
        }
        PersistenceController.shared.save()
    }

    // MARK: - HTTP
    private func post(path: String, body: [String: Any], completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: WORKER_URL + path) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(API_SECRET)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 15
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            completion?((resp as? HTTPURLResponse)?.statusCode == 200)
        }.resume()
    }

    private func get(path: String, completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: WORKER_URL + path) else { completion(nil); return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(API_SECRET)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15
        URLSession.shared.dataTask(with: req) { data, _, _ in
            completion(data)
        }.resume()
    }

    // MARK: - Dict helpers
    private func productDict(_ p: ProductEntity) -> [String: Any] {
        [
            "id": p.id?.uuidString ?? UUID().uuidString,
            "name": p.name ?? "",
            "sku": p.sku ?? "",
            "barcode": p.barcode ?? "",
            "category": p.category ?? "",
            "unit": p.unit ?? "db",
            "minStock": p.minStock,
            "currentStock": p.currentStock,
            "price": p.price,
            "location": p.location ?? "",
            "note": p.note ?? "",
            "createdAt": p.createdAt?.iso ?? Date().iso,
        ]
    }

    private func txDict(_ tx: TransactionEntity) -> [String: Any] {
        [
            "id": tx.id?.uuidString ?? UUID().uuidString,
            "productId": tx.productId?.uuidString ?? "",
            "productName": tx.productName ?? "",
            "type": tx.type ?? "",
            "quantity": tx.quantity,
            "note": tx.note ?? "",
            "deliveryNote": tx.deliveryNote ?? "",
            "timestamp": tx.timestamp?.iso ?? Date().iso,
            "user": tx.user ?? "",
            "stockBefore": tx.stockBefore,
            "stockAfter": tx.stockAfter,
        ]
    }
}

extension Date {
    var iso: String { ISO8601DateFormatter().string(from: self) }
    static func fromISO(_ s: String) -> Date? { ISO8601DateFormatter().date(from: s) }
}
