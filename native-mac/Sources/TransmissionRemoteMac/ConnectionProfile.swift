import Foundation

struct ConnectionProfile: Codable, Equatable {
    var rpcURLString: String
    var username: String
    var automaticallyConnect: Bool

    static let empty = ConnectionProfile(
        rpcURLString: "http://localhost:9091/transmission/rpc",
        username: "",
        automaticallyConnect: false
    )

    var keychainAccount: String {
        "\(rpcURLString)|\(username)"
    }

    init(
        rpcURLString: String,
        username: String,
        automaticallyConnect: Bool
    ) {
        self.rpcURLString = rpcURLString
        self.username = username
        self.automaticallyConnect = automaticallyConnect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rpcURLString = try container.decode(String.self, forKey: .rpcURLString)
        self.username = try container.decode(String.self, forKey: .username)
        self.automaticallyConnect = try container.decodeIfPresent(Bool.self, forKey: .automaticallyConnect) ?? true
    }
}

struct ConnectionDraft: Equatable {
    var rpcURLString: String
    var username: String
    var password: String
    var automaticallyConnect: Bool

    init(profile: ConnectionProfile, password: String) {
        self.rpcURLString = profile.rpcURLString
        self.username = profile.username
        self.password = password
        self.automaticallyConnect = profile.automaticallyConnect
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
