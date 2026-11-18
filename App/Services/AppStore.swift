import Foundation
import SwiftData
import Security

@Model
final class StoredSet {
    @Attribute(.unique) var identifier: UUID
    var date: Date
    var payload: Data
    init(record: SetRecord) throws {
        identifier = record.id; date = record.date
        payload = try JSONEncoder().encode(record)
    }
}

@Model
final class StoredPlan {
    @Attribute(.unique) var identifier: String
    var payload: Data
    init(_ plan: [PlannedExercise]) throws {
        identifier = "current"
        payload = try JSONEncoder().encode(plan)
    }
}

@MainActor
final class AppStore {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) throws {
        let schema = Schema([StoredSet.self, StoredPlan.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    func records() throws -> [SetRecord] {
        try context.fetch(FetchDescriptor<StoredSet>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
            .map { try JSONDecoder().decode(SetRecord.self, from: $0.payload) }
            .filter { !$0.isDemo }
    }

    func save(_ record: SetRecord) throws {
        context.insert(try StoredSet(record: record))
        try context.save()
    }

    func plan() throws -> [PlannedExercise]? {
        guard let value = try context.fetch(FetchDescriptor<StoredPlan>()).first else { return nil }
        return try JSONDecoder().decode([PlannedExercise].self, from: value.payload)
    }

    func savePlan(_ plan: [PlannedExercise]) throws {
        if let stored = try context.fetch(FetchDescriptor<StoredPlan>()).first {
            stored.payload = try JSONEncoder().encode(plan)
        } else {
            context.insert(try StoredPlan(plan))
        }
        try context.save()
    }

    func deleteHistory() throws {
        try context.delete(model: StoredSet.self)
        try context.save()
    }
}

enum CredentialStore {
    private static let service = "app.afterburn.meter.smartspectra"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "api-key"]
    }

    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &value) == errSecSuccess,
              let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeyError.status(added) }
        } else if status != errSecSuccess { throw KeyError.status(status) }
    }

    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyError.status(status)
        }
    }

    enum KeyError: LocalizedError {
        case status(OSStatus)
        var errorDescription: String? {
            switch self {
            case .status(let status):
                return "Keychain could not update the credential (\(status)). Check app signing and Keychain access."
            }
        }
    }
}

