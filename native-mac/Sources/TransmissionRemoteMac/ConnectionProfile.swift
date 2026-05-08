import Foundation

struct ConnectionProfile: Codable, Equatable {
    var rpcURLString: String
    var username: String

    static let empty = ConnectionProfile(
        rpcURLString: "http://localhost:9091/transmission/rpc",
        username: ""
    )

    var keychainAccount: String {
        "\(rpcURLString)|\(username)"
    }
}

struct ConnectionDraft: Equatable {
    var rpcURLString: String
    var username: String
    var password: String

    init(profile: ConnectionProfile, password: String) {
        self.rpcURLString = profile.rpcURLString
        self.username = profile.username
        self.password = password
    }
}

struct ConnectionProfileStore {
    var load: @MainActor () -> ConnectionProfile
    var save: @MainActor (ConnectionProfile) throws -> Void

    static let live = ConnectionProfileStore(
        load: {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let profile = try? JSONDecoder().decode(ConnectionProfile.self, from: data) else {
                return .empty
            }
            return profile
        },
        save: { profile in
            let data = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    )

    private static let storageKey = "connection-profile"
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
