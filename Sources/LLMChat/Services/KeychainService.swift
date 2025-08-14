import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.llmchat.apikeys"
    private let apiKeyAccount = "openrouter_api_key"
    
    private init() {}
    
    // MARK: - API Key Management
    
    func saveAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unableToSave(status)
        }
    }
    
    func getAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.unableToRetrieve(status)
        }
        
        guard let data = dataRef as? Data else {
            throw KeychainError.invalidData
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }
    
    // MARK: - Convenience Methods
    
    var hasAPIKey: Bool {
        do {
            return try getAPIKey() != nil
        } catch {
            return false
        }
    }
    
    func validateAPIKey(_ key: String) -> Bool {
        // Basic validation - OpenRouter API keys typically start with "sk-or-"
        return key.hasPrefix("sk-or-") && key.count > 20
    }
}

// MARK: - Error Handling

enum KeychainError: Error, LocalizedError {
    case unableToSave(OSStatus)
    case unableToRetrieve(OSStatus)
    case unableToDelete(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .unableToSave(let status):
            return "Unable to save to Keychain (status: \(status))"
        case .unableToRetrieve(let status):
            return "Unable to retrieve from Keychain (status: \(status))"
        case .unableToDelete(let status):
            return "Unable to delete from Keychain (status: \(status))"
        case .invalidData:
            return "Invalid data in Keychain"
        }
    }
}