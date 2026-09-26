import Foundation

public enum MedicineUnit: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case tablets
    case capsules
    case doses
    case milliliters
    case packets
    case units

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .tablets: return "tablets"
        case .capsules: return "capsules"
        case .doses: return "doses"
        case .milliliters: return "ml"
        case .packets: return "packets"
        case .units: return "units"
        }
    }
}

public struct MedicineInventoryItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var purpose: String
    public var strength: String
    public var quantity: Int
    public var unit: MedicineUnit
    public var expiryDate: Date
    public var storageLocation: String
    public var lowStockThreshold: Int
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        purpose: String = "",
        strength: String = "",
        quantity: Int = 0,
        unit: MedicineUnit = .tablets,
        expiryDate: Date,
        storageLocation: String = "",
        lowStockThreshold: Int = 5,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.purpose = purpose
        self.strength = strength
        self.quantity = max(0, quantity)
        self.unit = unit
        self.expiryDate = expiryDate
        self.storageLocation = storageLocation
        self.lowStockThreshold = max(0, lowStockThreshold)
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isLowStock: Bool { quantity <= lowStockThreshold }

    public func expiryState(relativeTo date: Date = .now, calendar: Calendar = .current) -> ExpiryState {
        let today = calendar.startOfDay(for: date)
        let expiry = calendar.startOfDay(for: expiryDate)
        if expiry < today { return .expired }
        let warningDate = calendar.date(byAdding: .day, value: 30, to: today) ?? today
        if expiry <= warningDate { return .expiringSoon }
        return .ok
    }
}

public enum ExpiryState: String, Hashable, Sendable {
    case ok
    case expiringSoon
    case expired
}
