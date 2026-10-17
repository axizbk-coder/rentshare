import SwiftUI
import UIKit
import WebKit
import Security
import CoreLocation
import AuthenticationServices
import CryptoKit

private let rentShareOrigin = "https://rentshare-turon.feylily2.chatgpt.site"
private let rentShareKeyService = "uz.rentshare.ios.device-access"
#if APPSTORE
private let rentShareAppStore = true
#else
private let rentShareAppStore = false
#endif

private enum RentShareChrome {
    static func color(dark: Bool) -> UIColor {
        dark ? UIColor(red:16/255,green:36/255,blue:31/255,alpha:1) : UIColor(red:243/255,green:248/255,blue:248/255,alpha:1)
    }
}

struct ConnectedRootView: View {
    @AppStorage("rentshare.appearance") private var appearance = "light"
    var body: some View {
        OnlineRentShareView(appearance: appearance)
            .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
    }
}

struct OnlineRentShareView: View {
    let appearance: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var failed = false
    @State private var reload = UUID()
    @StateObject private var navigation = OnlineNavigation()
    private func text(_ uz:String,_ ru:String,_ en:String)->String { navigation.language == "ru" ? ru : navigation.language == "en" ? en : uz }
    var body: some View {
        ZStack {
            // Paint the actual safe areas, not just the web page's content rectangle.
            Color(uiColor: RentShareChrome.color(dark: appearance == "dark" || appearance == "system" && colorScheme == .dark))
                .ignoresSafeArea(.container)
            OnlineWebView(reload: reload, failed: $failed, navigation: navigation, appearance: appearance)
            if failed {
                VStack(spacing: 20) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 55)).foregroundStyle(Brand.green)
                    Text(text("Serverga ulanib bo‘lmadi","Не удалось подключиться","Could not connect")).font(.title2.bold())
                    Text(text("Internetga ulanishni tekshiring. Ma’lumotlaringiz serverda saqlanadi.","Проверьте подключение. Ваши данные хранятся на сервере.","Check your internet connection. Your data is stored on the server.")).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button(text("Qayta urinish","Повторить","Retry")) { failed = false; reload = UUID() }.buttonStyle(.borderedProminent)
                }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(uiColor: .systemBackground))
            }
        }
            .overlay(alignment: .bottom) {
                if !navigation.modalPresented && !navigation.keyboardPresented { GlassNavigation(navigation:navigation) }
            }
            .onReceive(NotificationCenter.default.publisher(for:UIResponder.keyboardWillShowNotification)) { _ in
                navigation.keyboardPresented=true
                navigation.webView?.evaluateJavaScript("window.RentShareKeyboardVisible=true;window.dispatchEvent(new Event('rentshare-keyboard'))")
            }
            .onReceive(NotificationCenter.default.publisher(for:UIResponder.keyboardWillHideNotification)) { _ in
                navigation.keyboardPresented=false
                navigation.webView?.evaluateJavaScript("window.RentShareKeyboardVisible=false;window.dispatchEvent(new Event('rentshare-keyboard'))")
            }
            .sheet(isPresented: $navigation.settingsPresented) { OnlineSettings(navigation: navigation) }
    }
}

private final class ChromeWebView: WKWebView {
    var updateChrome: (() -> Void)?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateChrome?()
    }
}

private enum DeviceAccess {
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: rentShareKeyService, kSecAttrAccount as String: "device-key"]
    }
    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ key: String) -> Bool {
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data(key.utf8)] as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var request = query
        request[kSecValueData as String] = Data(key.utf8)
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(request as CFDictionary, nil) == errSecSuccess
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}

struct OnlineWebView: UIViewRepresentable {
    var reload: UUID
    @Binding var failed: Bool
    var navigation: OnlineNavigation
    var appearance: String
    func makeCoordinator() -> Coordinator { Coordinator(failed: $failed, navigation: navigation) }
    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "rentShareAccess")
        context.coordinator.configure(controller)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .default()
        configuration.ignoresViewportScaleLimits = false
        let view = ChromeWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.isOpaque = false
        view.clipsToBounds = true
        view.scrollView.clipsToBounds = true
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.delegate = context.coordinator
        view.scrollView.pinchGestureRecognizer?.isEnabled = false
        context.coordinator.webView = view
        context.coordinator.appearance = appearance
        context.coordinator.darkAppearance = context.environment.colorScheme == .dark
        view.updateChrome = { [weak coordinator = context.coordinator] in coordinator?.applyNativeAppearance() }
        context.coordinator.applyNativeAppearance()
        navigation.webView = view
        context.coordinator.lastReload = reload
        view.load(URLRequest(url: URL(string: rentShareOrigin + "/")!))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.appearance = appearance
        context.coordinator.darkAppearance = context.environment.colorScheme == .dark
        context.coordinator.applyAppearance()
        context.coordinator.lockPageScale(view.scrollView)
        if context.coordinator.lastReload != reload {
            context.coordinator.lastReload = reload
            view.load(URLRequest(url: URL(string: rentShareOrigin + "/")!))
        }
    }
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIScrollViewDelegate, CLLocationManagerDelegate, ASWebAuthenticationPresentationContextProviding {
        var failed: Binding<Bool>
        var lastReload: UUID?
        weak var webView: WKWebView?
        var navigation: OnlineNavigation
        var darkAppearance = false
        var appearance = "light"
        func lockPageScale(_ scrollView: UIScrollView) {
            scrollView.pinchGestureRecognizer?.isEnabled = false
            if abs(scrollView.zoomScale - 1) > 0.001 { scrollView.setZoomScale(1, animated: false) }
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { nil }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { lockPageScale(scrollView) }
        func applyNativeAppearance() {
            guard let view = webView else { return }
            let style: UIUserInterfaceStyle = appearance == "system" ? .unspecified : appearance == "dark" ? .dark : .light
            if view.overrideUserInterfaceStyle != style { view.overrideUserInterfaceStyle = style }
            if let window = view.window, window.overrideUserInterfaceStyle != style { window.overrideUserInterfaceStyle = style }
            let dark = appearance == "dark" || appearance == "system" && darkAppearance
            let canvas = RentShareChrome.color(dark: dark)
            view.backgroundColor = canvas
            view.scrollView.backgroundColor = canvas
            view.underPageBackgroundColor = canvas
            view.window?.backgroundColor = canvas
            view.window?.rootViewController?.view.backgroundColor = canvas
            view.window?.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        }
        func applyAppearance() {
            applyNativeAppearance()
            // The web Settings choice owns the theme; OS appearance is a fallback.
            webView?.evaluateJavaScript("try { if (!localStorage.getItem('rentshare.appearance')) document.documentElement.dataset.theme = '\(darkAppearance ? "dark" : "light")'; } catch (_) {}")
        }
        private var locationManager = CLLocationManager()
        private var authentication: ASWebAuthenticationSession?
        init(failed: Binding<Bool>, navigation:OnlineNavigation) { self.failed = failed; self.navigation=navigation;super.init();locationManager.delegate=self }
        func configure(_ controller: WKUserContentController) {
            controller.removeAllUserScripts()
            let keyJSON = String(data: try! JSONSerialization.data(withJSONObject: DeviceAccess.read() as Any? ?? NSNull(), options: [.fragmentsAllowed]), encoding: .utf8)!
            let script = """
            (() => {
                if (location.origin !== '\(rentShareOrigin)') return;
                let key = \(keyJSON);
                const originalFetch = window.fetch.bind(window);
                window.fetch = (input, init = {}) => {
                    const url = new URL(typeof input === 'string' ? input : input.url, location.href);
                    if (key && url.origin === location.origin && url.pathname.startsWith('/api/')) {
                        const headers = new Headers(init.headers || (input instanceof Request ? input.headers : undefined));
                        if (!headers.has('Authorization')) headers.set('Authorization', 'Bearer ' + key);
                        init = {...init, headers};
                    }
                    return originalFetch(input, init);
                };
                const apiRequests=new WeakSet();
                const xhrOpen=XMLHttpRequest.prototype.open,xhrSend=XMLHttpRequest.prototype.send;
                XMLHttpRequest.prototype.open=function(method,value,...args){const url=new URL(value,location.href);if(url.origin===location.origin&&url.pathname.startsWith('/api/'))apiRequests.add(this);else apiRequests.delete(this);return xhrOpen.call(this,method,value,...args);};
                XMLHttpRequest.prototype.send=function(body){if(key&&apiRequests.has(this))this.setRequestHeader('Authorization','Bearer '+key);return xhrSend.call(this,body);};
                let imageSequence=0;
                const imageRequests=new Map();
                window.RentShareImageResult=(id,error)=>{const pending=imageRequests.get(id);if(!pending)return;imageRequests.delete(id);error?pending.reject(new Error(error)):pending.resolve(true);};
                window.RentShareNative = {
                    saveFile: (value) => new Promise((resolve,reject)=>{const id=String(++imageSequence);imageRequests.set(id,{resolve,reject});window.webkit.messageHandlers.rentShareAccess.postMessage({action:'saveFile',id,data:value.data,mime:value.mime,name:value.name});setTimeout(()=>{if(imageRequests.has(id)){imageRequests.delete(id);reject(new Error('Save timed out'));}},180000);}),
                    saveImage: (value) => new Promise((resolve,reject)=>{const id=String(++imageSequence);imageRequests.set(id,{resolve,reject});window.webkit.messageHandlers.rentShareAccess.postMessage({action:'saveImage',id,data:value.data,mime:value.mime});setTimeout(()=>{if(imageRequests.has(id)){imageRequests.delete(id);reject(new Error('Save timed out'));}},180000);}),
                    mobile: true,
                    appStore: \(rentShareAppStore ? "true" : "false"),
                    beginAccountDeletion: (userId,language) => window.webkit.messageHandlers.rentShareAccess.postMessage({action:'deleteAccount',userId,language}),
                    navigationVersion: 2,
                    imageUploadProgress: true,
                    openSettings: () => window.webkit.messageHandlers.rentShareAccess.postMessage({action: 'settings'}),
                    syncNavigation: (page) => window.webkit.messageHandlers.rentShareAccess.postMessage({action: 'navigation', page}),
                    syncLanguage: (language) => window.webkit.messageHandlers.rentShareAccess.postMessage({action:'language',language}),
                    syncAppearance: (appearance) => window.webkit.messageHandlers.rentShareAccess.postMessage({action:'appearance',appearance}),
                    syncModal: (open) => window.webkit.messageHandlers.rentShareAccess.postMessage({action: 'modal', open: open ? 'true' : 'false'}),
                    saveKey: (value) => { key=value;window.webkit.messageHandlers.rentShareAccess.postMessage({action: 'save', key:value}); },
                    clearKey: () => { key=null;window.webkit.messageHandlers.rentShareAccess.postMessage({action: 'clear'}); },
                    requestLocation: () => window.webkit.messageHandlers.rentShareAccess.postMessage({action: 'location'}),
                    beginAuth: () => window.webkit.messageHandlers.rentShareAccess.postMessage({action: 'auth'})
                };
                // Restore native chrome from the same preference before the first page paints.
                try {
                    const appearance = localStorage.getItem('rentshare.appearance');
                    if (['light','dark','system'].includes(appearance)) window.RentShareNative.syncAppearance(appearance);
                } catch (_) {}
                const originalSet = Storage.prototype.setItem;
                const originalRemove = Storage.prototype.removeItem;
                Storage.prototype.setItem = function(name, value) {
                    if (this === localStorage && name === 'rentshare.device-key') {
                        window.RentShareNative.saveKey(String(value));
                        return;
                    }
                    return originalSet.call(this, name, value);
                };
                Storage.prototype.removeItem = function(name) {
                    if (this === localStorage && name === 'rentshare.device-key') window.RentShareNative.clearKey();
                    return originalRemove.call(this, name);
                };
            })();
            """
            controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
            let layoutScript = """
            if (location.origin === '\(rentShareOrigin)') {
                const viewport = document.querySelector('meta[name="viewport"]') || document.head.appendChild(document.createElement('meta'));
                viewport.name = 'viewport';
                viewport.content = 'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover';
                const nativeStyle = document.createElement('style');
                nativeStyle.textContent = '.mobile-nav{display:none!important}.app-shell{padding-bottom:112px!important}';
                document.head.appendChild(nativeStyle);
            }
            """
            controller.addUserScript(WKUserScript(source: layoutScript, injectionTime: .atDocumentEnd, forMainFrameOnly:true))
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.protocol == "https", message.frameInfo.securityOrigin.host == URL(string: rentShareOrigin)!.host,
                  let value = message.body as? [String: String] else { return }
            if value["action"] == "language", let language=value["language"], ["uz","ru","en"].contains(language) { navigation.language=language; UserDefaults.standard.set(language,forKey:"rentshare.language"); return }
            if value["action"] == "appearance", let appearance=value["appearance"], ["light","dark","system"].contains(appearance) {
                if UserDefaults.standard.string(forKey:"rentshare.appearance") != appearance { UserDefaults.standard.set(appearance,forKey:"rentshare.appearance") }
                self.appearance = appearance
                applyNativeAppearance()
                return
            }
            if value["action"] == "saveFile" { saveFile(value); return }
            if value["action"] == "saveImage" { saveImage(value); return }
            if value["action"] == "save", let key = value["key"], key.range(of: "^rs_[A-Za-z0-9_-]{40,}$", options: .regularExpression) != nil {
                guard DeviceAccess.save(key) else { failed.wrappedValue = true; return }
                configure(userContentController)
            } else if value["action"] == "clear" {
                DeviceAccess.clear()
                configure(userContentController)
            } else if value["action"] == "location" {
                if locationManager.authorizationStatus == .notDetermined { locationManager.requestWhenInUseAuthorization() }
                else if [.authorizedWhenInUse,.authorizedAlways].contains(locationManager.authorizationStatus) { locationManager.requestLocation() }
                else { emitLocation(["error":"Joylashuvga ruxsat berilmadi. Xaritadan qo‘lda belgilang."]) }
            } else if value["action"] == "auth" { beginAuthentication() }
            else if value["action"] == "deleteAccount", let userId=value["userId"], UUID(uuidString:userId) != nil {
                beginAccountDeletion(userId, language:value["language"] ?? "uz")
            }
            else if value["action"] == "settings" { navigation.settingsPresented = true }
            else if value["action"] == "modal" {
                navigation.modalPresented = value["open"] == "true"
                webView?.scrollView.bounces = !navigation.modalPresented
            }
            else if value["action"] == "navigation", let page = value["page"], ["home","search","dormitories","messages","profile","saved","mine","roommates","map"].contains(page) {
                let selected = ["saved","mine"].contains(page) ? "profile" : ["roommates","map"].contains(page) ? "search" : page
                navigation.updateSelection(selected)
            }
        }
        private func imageResult(_ id:String,_ error:String? = nil) {
            let result:[Any]=[id,error as Any? ?? NSNull()]
            guard let json=try? JSONSerialization.data(withJSONObject:result),let arguments=String(data:json,encoding:.utf8) else { return }
            webView?.evaluateJavaScript("window.RentShareImageResult?.(...\(arguments))")
        }
        func webView(_ webView:WKWebView,requestMediaCapturePermissionFor origin:WKSecurityOrigin,initiatedByFrame frame:WKFrameInfo,type:WKMediaCaptureType,decisionHandler:@escaping(WKPermissionDecision)->Void) { decisionHandler(origin.protocol == "https" && origin.host == URL(string:rentShareOrigin)?.host ? .prompt : .deny) }
        private func saveFile(_ value:[String:String]) {
            guard let id=value["id"],let encoded=value["data"],encoded.count<=20_000_000,let mime=value["mime"],["video/mp4","video/webm","audio/mp4","audio/webm","audio/ogg","audio/wav","audio/mpeg","application/pdf","application/zip","text/plain"].contains(mime),let data=Data(base64Encoded:encoded),!data.isEmpty,data.count<=15_000_000,let root=webView?.window?.rootViewController else { imageResult(value["id"] ?? "","Cannot save file");return }
            let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true),name=URL(fileURLWithPath:value["name"] ?? "RentShare-file").lastPathComponent,file=folder.appendingPathComponent(name.isEmpty ? "RentShare-file" : name)
            do { try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);try data.write(to:file,options:.atomic) } catch { imageResult(id,"Could not save file");return }
            var presenter=root;while let presented=presenter.presentedViewController { presenter=presented }
            let activity=UIActivityViewController(activityItems:[file],applicationActivities:nil)
            activity.completionWithItemsHandler={ [weak self] _,_,_,error in self?.imageResult(id,error == nil ? nil : "Could not save file");try? FileManager.default.removeItem(at:folder) }
            activity.popoverPresentationController?.sourceView=webView;activity.popoverPresentationController?.sourceRect=CGRect(x:(webView?.bounds.midX ?? 0),y:(webView?.bounds.midY ?? 0),width:1,height:1)
            presenter.present(activity,animated:true)
        }
        private func saveImage(_ value:[String:String]) {
            guard let id=value["id"],let encoded=value["data"],encoded.count<=1_700_000,
                  let mime=value["mime"],["image/jpeg","image/png","image/webp"].contains(mime),
                  let data=Data(base64Encoded:encoded),data.count<=1_250_000,let image=UIImage(data:data),
                  let root=webView?.window?.rootViewController else { imageResult(value["id"] ?? "","Cannot save this image");return }
            var presenter=root
            while let presented=presenter.presentedViewController { presenter=presented }
            let activity=UIActivityViewController(activityItems:[image],applicationActivities:nil)
            activity.completionWithItemsHandler={ [weak self] _,_,_,error in self?.imageResult(id,error == nil ? nil : "Could not save image") }
            activity.popoverPresentationController?.sourceView=webView
            activity.popoverPresentationController?.sourceRect=CGRect(x:(webView?.bounds.midX ?? 0),y:(webView?.bounds.midY ?? 0),width:1,height:1)
            presenter.present(activity,animated:true)
        }
        func locationManagerDidChangeAuthorization(_ manager:CLLocationManager) {
            if [.authorizedWhenInUse,.authorizedAlways].contains(manager.authorizationStatus) { manager.requestLocation() }
        }
        func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]) {
            if let location=locations.last { emitLocation(["latitude":location.coordinate.latitude,"longitude":location.coordinate.longitude]) }
        }
        func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) { emitLocation(["error":"Joylashuvni aniqlab bo‘lmadi. Xaritadan qo‘lda belgilang."]) }
        private func emitLocation(_ value:[String:Any]) {
            let json=String(data:try! JSONSerialization.data(withJSONObject:value),encoding:.utf8)!
            webView?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('rentshare-location',{detail:\(json)}))")
        }
        func presentationAnchor(for session:ASWebAuthenticationSession) -> ASPresentationAnchor { webView?.window ?? ASPresentationAnchor() }
        private func beginAccountDeletion(_ userId:String,language:String) {
            guard authentication == nil, let currentKey=DeviceAccess.read() else { return }
            let state=UUID().uuidString
            let locale=["uz","ru","en"].contains(language) ? language : "uz"
            guard let url=URL(string:rentShareOrigin+"/account/delete?userId="+userId+"&nativePlatform=ios&request="+state+"&lang="+locale) else { return }
            let session=ASWebAuthenticationSession(url:url,callbackURLScheme:"rentshare") { [weak self] callback,error in
                guard let self=self else { return };self.authentication=nil
                guard error==nil,let callback=callback,callback.host=="account-deleted",
                      URLComponents(url:callback,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name=="id"})?.value==state else { return }
                Task { @MainActor in
                    do {
                        var request=URLRequest(url:URL(string:rentShareOrigin+"/api/state")!)
                        request.setValue("Bearer "+currentKey,forHTTPHeaderField:"Authorization")
                        let (_,response)=try await URLSession.shared.data(for:request)
                        // A callback alone cannot delete credentials. Verify revocation.
                        guard (response as? HTTPURLResponse)?.statusCode==401 else { return }
                        DeviceAccess.clear()
                        _ = try? await self.webView?.evaluateJavaScript("localStorage.removeItem('rentshare.device-key')")
                        if let view=self.webView { self.configure(view.configuration.userContentController);view.load(URLRequest(url:URL(string:rentShareOrigin+"/")!)) }
                    } catch { self.failed.wrappedValue=true }
                }
            }
            session.presentationContextProvider=self;session.prefersEphemeralWebBrowserSession=false;authentication=session
            if !session.start() { authentication=nil }
        }
        private func beginAuthentication() {
            guard authentication == nil else { return }
            let verifier=UUID().uuidString+UUID().uuidString
            let challenge=SHA256.hash(data:Data(verifier.utf8)).map{String(format:"%02x",$0)}.joined()
            Task { @MainActor [self] in
                do {
                    let result=try await self.api("auth/native/start",["challenge":challenge])
                    guard let loginId=result["id"] as? String, let link=result["url"] as? String, let url=URL(string:link+"&nativePlatform=ios"+(rentShareAppStore ? "&client=ios-store" : "")) else { throw URLError(.badServerResponse) }
                    let session=ASWebAuthenticationSession(url:url,callbackURLScheme:"rentshare") { [weak self] callback,error in
                        guard let self=self else { return };self.authentication=nil
                        guard let callback=callback,error==nil,URLComponents(url:callback,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name=="id"})?.value==loginId else { return }
                        Task { @MainActor in
                            do { let result=try await self.api("auth/native/poll",["id":loginId,"verifier":verifier,"label":"iPhone"]);guard let key=result["key"] as? String,DeviceAccess.save(key) else { throw URLError(.userAuthenticationRequired) };self.configure(self.webView!.configuration.userContentController);self.webView?.reload() }
                            catch { self.failed.wrappedValue=true }
                        }
                    }
                    session.presentationContextProvider=self;session.prefersEphemeralWebBrowserSession=false;self.authentication=session
                    if !session.start() { self.authentication=nil;throw URLError(.cannotConnectToHost) }
                } catch { self.authentication=nil;self.failed.wrappedValue=true }
            }
        }
        private func api(_ endpoint:String,_ body:[String:String]) async throws -> [String:Any] {
            var request=URLRequest(url:URL(string:rentShareOrigin+"/api/"+endpoint)!);request.httpMethod="POST";request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody=try JSONSerialization.data(withJSONObject:body)
            let (data,response)=try await URLSession.shared.data(for:request);guard (response as? HTTPURLResponse)?.statusCode==200,let result=try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw URLError(.badServerResponse) };return result
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            lockPageScale(webView.scrollView)
            failed.wrappedValue = false
            applyAppearance()
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failed.wrappedValue = true }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failed.wrappedValue = true }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            let authHosts = ["chatgpt.com", "auth.openai.com", "auth0.openai.com", "accounts.google.com", "appleid.apple.com", "login.microsoftonline.com"]
            if url.scheme == "https" && (url.host == URL(string: rentShareOrigin)!.host || authHosts.contains(url.host ?? "")) { decisionHandler(.allow) }
            else {
                if ["https", "tel", "mailto"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
                decisionHandler(.cancel)
            }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url, ["https", "tel", "mailto"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
            return nil
        }
    }
}
