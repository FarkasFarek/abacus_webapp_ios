import CoreData
import Foundation

@objc(ProductEntity)
public class ProductEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var sku: String?
    @NSManaged public var barcode: String?
    @NSManaged public var category: String?
    @NSManaged public var unit: String?
    @NSManaged public var minStock: Double
    @NSManaged public var currentStock: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var note: String?
    @NSManaged public var price: Double
    @NSManaged public var location: String?
}

extension ProductEntity: Identifiable {}
extension ProductEntity {
    static func fetchRequest() -> NSFetchRequest<ProductEntity> {
        NSFetchRequest<ProductEntity>(entityName: "ProductEntity")
    }
    var isLowStock: Bool { currentStock <= minStock && minStock > 0 }
    var isOutOfStock: Bool { currentStock <= 0 }
    var stockStatus: StockStatus {
        if isOutOfStock { return .outOfStock }
        if isLowStock { return .low }
        return .ok
    }
}

enum StockStatus {
    case ok, low, outOfStock
    var color: Color {
        switch self {
        case .ok: return .green
        case .low: return .orange
        case .outOfStock: return .red
        }
    }
    var label: String {
        switch self {
        case .ok: return "Rendben"
        case .low: return "Alacsony"
        case .outOfStock: return "Elfogyott"
        }
    }
}

import SwiftUI

@objc(TransactionEntity)
public class TransactionEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var productId: UUID?
    @NSManaged public var productName: String?
    @NSManaged public var type: String?
    @NSManaged public var quantity: Double
    @NSManaged public var note: String?
    @NSManaged public var deliveryNote: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var user: String?
    @NSManaged public var stockBefore: Double
    @NSManaged public var stockAfter: Double
}

extension TransactionEntity: Identifiable {}
extension TransactionEntity {
    static func fetchRequest() -> NSFetchRequest<TransactionEntity> {
        NSFetchRequest<TransactionEntity>(entityName: "TransactionEntity")
    }
    var transactionType: TransactionType {
        TransactionType(rawValue: type ?? "") ?? .stockIn
    }
}

enum TransactionType: String, CaseIterable {
    case stockIn = "BE"
    case stockOut = "KI"
    case inventory = "LELTÁR"
    case correction = "KORREKCIÓ"
    case waste = "SELEJT"

    var label: String {
        switch self {
        case .stockIn: return "Bevét"
        case .stockOut: return "Kivét"
        case .inventory: return "Leltár"
        case .correction: return "Korrekció"
        case .waste: return "Selejt"
        }
    }
    var icon: String {
        switch self {
        case .stockIn: return "arrow.down.circle.fill"
        case .stockOut: return "arrow.up.circle.fill"
        case .inventory: return "list.clipboard.fill"
        case .correction: return "pencil.circle.fill"
        case .waste: return "trash.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .stockIn: return .green
        case .stockOut: return .blue
        case .inventory: return .purple
        case .correction: return .orange
        case .waste: return .red
        }
    }
}

@objc(CategoryEntity)
public class CategoryEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var color: String?
}
extension CategoryEntity: Identifiable {}
extension CategoryEntity {
    static func fetchRequest() -> NSFetchRequest<CategoryEntity> {
        NSFetchRequest<CategoryEntity>(entityName: "CategoryEntity")
    }
}
