import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "InventoryModel",
            managedObjectModel: PersistenceController.makeModel()
        )
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("CoreData: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let productEntity = NSEntityDescription()
        productEntity.name = "ProductEntity"
        productEntity.managedObjectClassName = "ProductEntity"
        productEntity.properties = [
            makeAttr("id", type: .UUIDAttributeType),
            makeAttr("name", type: .stringAttributeType),
            makeAttr("sku", type: .stringAttributeType),
            makeAttr("barcode", type: .stringAttributeType),
            makeAttr("category", type: .stringAttributeType),
            makeAttr("unit", type: .stringAttributeType),
            makeAttr("minStock", type: .doubleAttributeType, default: 0.0),
            makeAttr("currentStock", type: .doubleAttributeType, default: 0.0),
            makeAttr("createdAt", type: .dateAttributeType),
            makeAttr("note", type: .stringAttributeType, optional: true),
            makeAttr("price", type: .doubleAttributeType, default: 0.0),
            makeAttr("location", type: .stringAttributeType, optional: true)
        ]
        let txEntity = NSEntityDescription()
        txEntity.name = "TransactionEntity"
        txEntity.managedObjectClassName = "TransactionEntity"
        txEntity.properties = [
            makeAttr("id", type: .UUIDAttributeType),
            makeAttr("productId", type: .UUIDAttributeType),
            makeAttr("productName", type: .stringAttributeType),
            makeAttr("type", type: .stringAttributeType),
            makeAttr("quantity", type: .doubleAttributeType, default: 0.0),
            makeAttr("note", type: .stringAttributeType, optional: true),
            makeAttr("deliveryNote", type: .stringAttributeType, optional: true),
            makeAttr("timestamp", type: .dateAttributeType),
            makeAttr("user", type: .stringAttributeType, optional: true),
            makeAttr("stockBefore", type: .doubleAttributeType, default: 0.0),
            makeAttr("stockAfter", type: .doubleAttributeType, default: 0.0)
        ]
        let catEntity = NSEntityDescription()
        catEntity.name = "CategoryEntity"
        catEntity.managedObjectClassName = "CategoryEntity"
        catEntity.properties = [
            makeAttr("id", type: .UUIDAttributeType),
            makeAttr("name", type: .stringAttributeType),
            makeAttr("color", type: .stringAttributeType, default: "blue")
        ]
        model.entities = [productEntity, txEntity, catEntity]
        return model
    }

    private static func makeAttr(_ name: String, type: NSAttributeType, default dv: Any? = nil, optional: Bool = false) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name; a.attributeType = type; a.isOptional = optional
        if let dv = dv { a.defaultValue = dv }
        return a
    }

    func save() {
        let ctx = container.viewContext
        if ctx.hasChanges { try? ctx.save() }
    }
}
