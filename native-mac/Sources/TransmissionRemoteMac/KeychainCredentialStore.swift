import Foundation
import Security

struct KeychainCredentialStore {
    var password: @MainActor (String) throws -> String?
    var savePassword: @MainActor (String, String) throws -> Void

    @MainActor
    func password(for account: String) throws -> String? {
        try password(account)
    }

    @MainActor
    func savePassword(_ password: String, for account: String) throws {
        try savePassword(password, account)
    }

    static let live = KeychainCredentialStore(
        password: { account in
            var query = baseQuery(account: account)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            if status == errSecItemNotFound {
                return nil
            }

            guard status == errSecSuccess else {
                throw KeychainError.unhandledStatus(status)
            }

            guard let data = item as? Data else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        },
        savePassword: { password, account in
            let encodedPassword = Data(password.utf8)
            var query = baseQuery(account: account)
            let attributes = [kSecValueData as String: encodedPassword]

            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecSuccess {
                return
            }

            if status == errSecItemNotFound {
                query[kSecValueData as String] = encodedPassword
                let addStatus = SecItemAdd(query as CFDictionary, nil)
                guard addStatus == errSecSuccess else {
                    throw KeychainError.unhandledStatus(addStatus)
                }
                return
            }

            throw KeychainError.unhandledStatus(status)
        }
    )

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "TransmissionRemoteMac.TransmissionRPC",
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            "Keychain error \(status)"
        }
    }
}
