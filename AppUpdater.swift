import Foundation

enum UpdaterError: Error {
    case invalidBundle
    case invalidResponse
    case other(description: String)
    
    var reason: String {
        switch self {
        case .invalidResponse:
            return "Invalid responce"
        case .invalidBundle:
            return "Invalid bundle"
        case .other(let description):
            return description
        }
    }
}

struct Version: Comparable {
    static func < (lhs: Version, rhs: Version) -> Bool {
        return lhs.base == rhs.base && lhs.major == rhs.major && lhs.minor < rhs.minor
    }
    
    init?(str: String) {
        let numbers = str.components(separatedBy: ".").compactMap({ Int($0) })
        
        guard numbers.count == 3 else {
            return nil
        }
        
        base = numbers[0]
        major = numbers[1]
        minor = numbers[2]
    }
    
    let base: Int
    let major: Int
    let minor: Int
}

struct AppUpdater {
    static func checkIfUpdateNeeded(_ completion: @escaping (Bool, UpdaterError?) -> ()) {
        guard let info = Bundle.main.infoDictionary,
            let currentVersion = info["CFBundleShortVersionString"] as? String,
            let identifier = info["CFBundleIdentifier"] as? String,
            let url = URL(string: "http://itunes.apple.com/lookup?bundleId=\(identifier)") else {
                completion(false, UpdaterError.invalidBundle)
                return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            do {
                if let error = error { throw error }
                guard let data = data else {
                    completion(false, UpdaterError.invalidResponse)
                    return
                }
                
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any]
                guard let result = (json?["results"] as? [Any])?.first as? [String: Any], let version = result["version"] as? String else {
                    completion(false, UpdaterError.invalidResponse)
                    return
                }
                
                guard let v = Version(str: version), let cv = Version(str: currentVersion) else {
                    completion(false, UpdaterError.invalidResponse)
                    return
                }
                completion(cv < v, nil)
            } catch {
                completion(false, UpdaterError.other(description: error.localizedDescription))
            }
        }
        task.resume()
    }
}
