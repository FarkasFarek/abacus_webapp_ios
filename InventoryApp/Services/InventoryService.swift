import CoreData
import Foundation

class InventoryService {
    static let shared = InventoryService()
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func fetchProducts(searchText: String = "", category: String = "") -> [ProductEntity] {
        let req = ProductEntity.fetchRequest()
        var predicates: [NSPredicate] = []
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@ OR sku CONTAINS[cd] %@ OR barcode CONTAINS[cd] %@", searchText, searchText, searchText))
        }
        if !category.isEmpty {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        if !predicates.isEmpty {
            req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    func findProduct(byBarcode barcode: String) -> ProductEntity? {
        let req = ProductEntity.fetchRequest()
        req.predicate = NSPredicate(format: "barcode == %@ OR sku == %@", barcode, barcode)
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first
    }

    @discardableResult
    func addProduct(name: String, sku: String, barcode: String, category: String,
                    unit: String, minStock: Double, price: Double,
                    location: String = "", note: String = "") -> ProductEntity {
        let p = ProductEntity(context: context)
        p.id = UUID()
        p.name = name
        p.sku = sku.isEmpty ? UUID().uuidString.prefix(8).lowercased().description : sku
        p.barcode = barcode.isEmpty ? p.sku : barcode
        p.category = category
        p.unit = unit
        p.minStock = minStock
        p.currentStock = 0
        p.price = price
        p.location = location
        p.note = note
        p.createdAt = Date()
        PersistenceController.shared.save()
        SyncService.shared.pushProduct(p)
        return p
    }

    func updateProduct(_ product: ProductEntity, name: String, sku: String, barcode: String,
                       category: String, unit: String, minStock: Double,
                       price: Double, location: String, note: String) {
        product.name = name
        product.sku = sku
        product.barcode = barcode
        product.category = category
        product.unit = unit
        product.minStock = minStock
        product.price = price
        product.location = location
        product.note = note
        PersistenceController.shared.save()
        SyncService.shared.pushProduct(product)
    }

    func deleteProduct(_ product: ProductEntity) {
        context.delete(product)
        PersistenceController.shared.save()
    }

    func recordTransaction(product: ProductEntity, type: TransactionType,
                           quantity: Double, note: String,
                           deliveryNote: String = "", user: String = "") {
        let tx = TransactionEntity(context: context)
        tx.id = UUID()
        tx.productId = product.id
        tx.productName = product.name
        tx.type = type.rawValue
        tx.quantity = quantity
        tx.note = note
        tx.deliveryNote = deliveryNote
        tx.timestamp = Date()
        tx.user = user
        tx.stockBefore = product.currentStock
        switch type {
        case .stockIn:
            product.currentStock += quantity
        case .stockOut, .waste:
            product.currentStock = max(0, product.currentStock - quantity)
        case .inventory, .correction:
            product.currentStock = quantity
        }
        tx.stockAfter = product.currentStock
        PersistenceController.shared.save()
        SyncService.shared.pushProduct(product)
        SyncService.shared.pushTransaction(tx)
    }

    func fetchTransactions(for product: ProductEntity? = nil, limit: Int = 100) -> [TransactionEntity] {
        let req = TransactionEntity.fetchRequest()
        if let p = product {
            req.predicate = NSPredicate(format: "productId == %@", p.id! as CVarArg)
        }
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        req.fetchLimit = limit
        return (try? context.fetch(req)) ?? []
    }

    func fetchCategories() -> [String] {
        let all = fetchProducts().compactMap { $0.category }.filter { !$0.isEmpty }
        return Array(Set(all)).sorted()
    }

    func dashboardStats() -> DashboardStats {
        let products = fetchProducts()
        let transactions = fetchTransactions(limit: 1000)
        let lowStock = products.filter { $0.isLowStock || $0.isOutOfStock }
        let totalValue = products.reduce(0.0) { $0 + $1.currentStock * $1.price }
        let todayTx = transactions.filter {
            guard let ts = $0.timestamp else { return false }
            return Calendar.current.isDateInToday(ts)
        }
        return DashboardStats(
            totalProducts: products.count,
            lowStockCount: lowStock.count,
            totalValue: totalValue,
            todayTransactions: todayTx.count,
            lowStockProducts: Array(lowStock.prefix(5))
        )
    }
}

struct DashboardStats {
    let totalProducts: Int
    let lowStockCount: Int
    let totalValue: Double
    let todayTransactions: Int
    let lowStockProducts: [ProductEntity]
}
