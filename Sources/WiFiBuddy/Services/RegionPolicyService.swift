import Foundation
import Observation

@MainActor
@Observable
final class RegionPolicyService {
    var document = RegionPolicyDocument.fallback
    var regionOverride: String?

    init() {
        loadFromBundle()
    }

    func setRegionOverride(_ code: String?) {
        regionOverride = code?.normalizedRegionCode
    }

    func effectiveCountryCode(interfaceCountry: String?, networkCountry: String?) -> String? {
        regionOverride ?? interfaceCountry?.normalizedRegionCode ?? networkCountry?.normalizedRegionCode
    }

    func effectivePolicy(interfaceCountry: String?, networkCountry: String?) -> RegionPolicy {
        document.policy(for: effectiveCountryCode(interfaceCountry: interfaceCountry, networkCountry: networkCountry))
    }

    func channels(
        for band: WiFiBand,
        interfaceCountry: String?,
        networkCountry: String?,
        supportedChannels: [Int]
    ) -> [Int] {
        let policy = effectivePolicy(interfaceCountry: interfaceCountry, networkCountry: networkCountry)
        guard let capability = policy.capability(for: band) else { return [] }
        if supportedChannels.isEmpty {
            return capability.channels
        }
        let filtered = capability.channels.filter { supportedChannels.contains($0) }
        return filtered.isEmpty ? capability.channels : filtered
    }

    func allPolicies() -> [RegionPolicy] {
        document.policies.sorted { $0.displayName < $1.displayName }
    }

    private func loadFromBundle() {
        guard let url = RegionPolicyResourceLocator.policyDocumentURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(RegionPolicyDocument.self, from: data) else {
            return
        }
        document = decoded
    }
}

private enum RegionPolicyResourceLocator {
    private static let bundleName = "WiFiBuddy_WiFiBuddy.bundle"
    private static let fileName = "region_policies.json"

    static func policyDocumentURL() -> URL? {
        let fileManager = FileManager.default

        for directory in candidateDirectories() {
            let directFile = directory.appendingPathComponent(fileName, isDirectory: false)
            if fileManager.fileExists(atPath: directFile.path) {
                return directFile
            }

            let bundledFile = directory
                .appendingPathComponent(bundleName, isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false)
            if fileManager.fileExists(atPath: bundledFile.path) {
                return bundledFile
            }
        }

        return nil
    }

    private static func candidateDirectories() -> [URL] {
        let probeBundles = [
            Bundle.main,
            Bundle(for: ResourceProbe.self)
        ]

        var directories: [URL] = []
        var seenPaths = Set<String>()

        func appendHierarchy(startingAt url: URL?) {
            guard var current = url?.standardizedFileURL else { return }

            for _ in 0..<8 {
                let path = current.path
                if seenPaths.insert(path).inserted {
                    directories.append(current)
                }

                let parent = current.deletingLastPathComponent()
                if parent.path == current.path {
                    break
                }
                current = parent
            }
        }

        for bundle in probeBundles {
            appendHierarchy(startingAt: bundle.resourceURL)
            appendHierarchy(startingAt: bundle.bundleURL)
            appendHierarchy(startingAt: bundle.executableURL?.deletingLastPathComponent())
        }

        return directories
    }

    private final class ResourceProbe: NSObject {}
}
