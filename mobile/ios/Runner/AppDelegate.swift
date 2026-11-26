import CFNetwork
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let channelName = "com.aiproxylauncher/native"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: channelName,
                binaryMessenger: controller.binaryMessenger
            )
            channel.setMethodCallHandler { [weak self] call, result in
                guard let self = self else {
                    result(nil)
                    return
                }
                switch call.method {
                case "getAppDataDir":
                    result(self.appDataDirectory())
                case "getNetworkState":
                    result(self.collectNetworkState())
                case "getInstalledApps":
                    let args = call.arguments as? [String: Any]
                    let schemes = args?["schemes"] as? [String] ?? []
                    result(self.queryInstalledSchemes(schemes))
                case "launchApp":
                    let args = call.arguments as? [String: Any]
                    let scheme = args?["scheme"] as? String
                    let url = args?["url"] as? String
                    self.launchAppOrUrl(scheme: scheme, fallbackUrl: url, completion: result)
                case "openUrl":
                    let args = call.arguments as? [String: Any]
                    let url = args?["url"] as? String
                    self.openExternalUrl(url, completion: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func appDataDirectory() -> String {
        let fm = FileManager.default
        if let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = base.appendingPathComponent("AIProxyLauncher", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.path
        }
        return NSTemporaryDirectory()
    }

    private func collectNetworkState() -> [String: Any?] {
        var vpnActive = false
        var vpnIfaces: [String] = []
        var httpHost: String?
        var httpPort: Int?
        var socksHost: String?
        var socksPort: Int?

        if let dict = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] {
            if let scoped = dict["__SCOPED__"] as? [String: Any] {
                for key in scoped.keys {
                    let lower = key.lowercased()
                    if lower.hasPrefix("utun") || lower.hasPrefix("tap") || lower.hasPrefix("tun")
                        || lower.hasPrefix("ppp") || lower.hasPrefix("ipsec")
                    {
                        vpnActive = true
                        vpnIfaces.append(key)
                    }
                }
            }
            if let httpEnable = dict["HTTPEnable"] as? Int, httpEnable == 1,
                let host = dict["HTTPProxy"] as? String, !host.isEmpty,
                let port = dict["HTTPPort"] as? Int, (1...65535).contains(port)
            {
                httpHost = host
                httpPort = port
            } else if let httpsEnable = dict["HTTPSEnable"] as? Int, httpsEnable == 1,
                let host = dict["HTTPSProxy"] as? String, !host.isEmpty,
                let port = dict["HTTPSPort"] as? Int, (1...65535).contains(port)
            {
                httpHost = host
                httpPort = port
            }
            if let socksEnable = dict["SOCKSEnable"] as? Int, socksEnable == 1,
                let host = dict["SOCKSProxy"] as? String, !host.isEmpty,
                let port = dict["SOCKSPort"] as? Int, (1...65535).contains(port)
            {
                socksHost = host
                socksPort = port
            }
        }

        let ver = UIDevice.current.systemVersion
        return [
            "platform": "ios",
            "osVersion": "iOS \(ver)",
            "vpnActive": vpnActive,
            "vpnInterfaces": vpnIfaces,
            "httpProxyHost": httpHost,
            "httpProxyPort": httpPort,
            "socksProxyHost": socksHost,
            "socksProxyPort": socksPort,
        ]
    }

    private func queryInstalledSchemes(_ schemes: [String]) -> [String] {
        var installed: [String] = []
        for raw in schemes {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let target = trimmed.contains("://") ? trimmed : "\(trimmed)://"
            if let url = URL(string: target), UIApplication.shared.canOpenURL(url) {
                installed.append(raw)
            }
        }
        return installed
    }

    private func launchAppOrUrl(
        scheme: String?,
        fallbackUrl: String?,
        completion: @escaping FlutterResult
    ) {
        if let raw = scheme, !raw.isEmpty {
            let formatted = raw.contains("://") ? raw : "\(raw)://"
            if let url = URL(string: formatted), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { ok in
                    if ok {
                        completion(true)
                    } else {
                        self.openExternalUrl(fallbackUrl, completion: completion)
                    }
                }
                return
            }
        }
        openExternalUrl(fallbackUrl, completion: completion)
    }

    private func openExternalUrl(_ rawUrl: String?, completion: @escaping FlutterResult) {
        guard let rawUrl = rawUrl, !rawUrl.isEmpty, let url = URL(string: rawUrl) else {
            completion(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { ok in
            completion(ok)
        }
    }
}

