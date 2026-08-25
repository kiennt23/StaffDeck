import Foundation
import Security

struct TursoCredentials: Equatable, Sendable {
    var databaseURL: String
    var authToken: String
}

enum KeychainStore {
    private static let service = "tech.maneki.staffdeck.turso"

    static func save(_ credentials: TursoCredentials) throws {
        try save(credentials.databaseURL, account: "database-url")
        try save(credentials.authToken, account: "auth-token")
    }

    static func load() -> TursoCredentials? {
        guard
            let url = load(account: "database-url"),
            let token = load(account: "auth-token"),
            !url.isEmpty,
            !token.isEmpty
        else { return nil }
        return TursoCredentials(databaseURL: url, authToken: token)
    }

    static func delete() {
        for account in ["database-url", "auth-token"] {
            SecItemDelete([
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ] as CFDictionary)
        }
    }

    private static func save(_ value: String, account: String) throws {
        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(base as CFDictionary)
        var query = base
        query[kSecValueData] = Data(value.utf8)
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private static func load(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
