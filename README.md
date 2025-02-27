# WEO (Weboff)
![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) 
[![SPM](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![WEO]([https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager](https://www.canva.com/design/DAGU_YiRiu4/4Sw-MjjIVjHmw3m7udkMgQ/edit?utm_content=DAGU_YiRiu4&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton))


## Author (WEO)

Samuel Campos de Andrade

## License (WEO)

WEO is available under the MIT license. See the LICENSE file for more info.

### Install (WEO)

```swift
import WEO
```

#### (https://github.com/SAMISsw/Weboff)

### Code for Example

```swift
import SwiftUI
import WebKit
import WEO

struct ContentView: View {
    @StateObject private var viewModel = BrowserViewModel()

    var body: some View {
        NavigationView {
            VStack {
                Text("WEO")
                    .font(.custom("Impact", size: 24))
                    .padding()
                    .foregroundColor(.blue)
                    .animation(.easeInOut(duration: 2))

                HStack {
                    TextField("Enter URL", text: $viewModel.urlString, onCommit: {
                        viewModel.loadURL()
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                    Button(action: {
                        viewModel.goBack()
                    }) {
                        Image(systemName: "arrow.left")
                    }
                    .padding(.trailing)
                    .disabled(!viewModel.canGoBack)

                    Button(action: {
                        viewModel.goForward()
                    }) {
                        Image(systemName: "arrow.right")
                    }
                    .padding(.trailing)
                    .disabled(!viewModel.canGoForward)
                }

                WebView(viewModel: viewModel)
                HStack {
                    Button(action: {
                        viewModel.showSavedPages.toggle()
                    }) {
                        Image(systemName: "menucard")
                            .padding()
                    }
                    if viewModel.showSavedPages {
                        SavedPagesView(viewModel: viewModel)
                    }
                }
            }
            .navigationBarTitle("Advanced Browser", displayMode: .inline)
        }
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel

    func makeUIView(context: Context) -> WKWebView {
        let webview = WKWebView()
        webview.navigationDelegate = context.coordinator
        webview.configuration.preferences.javaScriptEnabled = true
        return webview
    }

    func updateUIView(_ webview: WKWebView, context: Context) {
        if let url = viewModel.currentURL {
            webview.load(URLRequest(url: url))
        } else {
            webview.loadHTMLString(viewModel.offlineHTML, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var viewModel: BrowserViewModel

        init(viewModel: BrowserViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.saveCurrentPage(html: webView.html)
            viewModel.updateNavigationState(webView)
        }
    }
}

struct SavedPagesView: View {
    @ObservedObject var viewModel: BrowserViewModel

    var body: some View {
        List {
            ForEach(viewModel.savedPages, id: \.self) { page in
                Text(page)
                    .onTapGesture {
                        viewModel.loadPage(page)
                    }
            }
            .onDelete(perform: viewModel.deletePage)
        }
    }
}

class BrowserViewModel: ObservableObject {
    @Published var currentURL: URL?
    @Published var showSavedPages = false
    @Published var savedPages: [String] = []
    @Published var urlString: String = ""
    @Published var offlineHTML: String = ""
    @Published var canGoBack = false
    @Published var canGoForward = false

    private let weo = WEO()
    private var webView: WKWebView?

    func loadURL() {
        if let url = URL(string: urlString) {
            currentURL = url
            loadURLRequest(URLRequest(url: url))
        }
    }

    func saveCurrentPage(html: String) {
        weo.saveHTMLContent(url: currentURL, html: html)
        offlineHTML = html
        downloadAssets(from: html)
        cacheResources(for: html)
    }

    func loadPage(_ page: String) {
        if let url = URL(string: page) {
            currentURL = url
            loadURLRequest(URLRequest(url: url))
        }
    }

    func deletePage(at offsets: IndexSet) {
        savedPages.remove(atOffsets: offsets)
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func updateNavigationState(_ webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func downloadAssets(from html: String) {
        let imagePattern = "src=[\"'](http[s]?://[^\"']+\\.(jpg|jpeg|png|gif))[\"']"
        downloadContent(withPattern: imagePattern, from: html)

        let videoPattern = "src=[\"'](http[s]?://[^\"']+\\.(mp4|mov|avi))[\"']"
        downloadContent(withPattern: videoPattern, from: html)

        let cssPattern = "<link rel=[\"']stylesheet[\"'] href=[\"'](.*?)[\"'][^>]*>"
        downloadContent(withPattern: cssPattern, from: html)

        let jsPattern = "<script src=[\"'](.*?)[\"'][^>]*></script>"
        downloadContent(withPattern: jsPattern, from: html)

        let linkPattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        downloadContent(withPattern: linkPattern, from: html)
    }

    func downloadContent(withPattern pattern: String, from html: String) {
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let url = String(html[range])
                    _ = weo.downloadContent(from: url)
                }
            }
        }
    }

    func loadOfflineContent(for url: String) {
        if let cachedHTML = weo.loadCachedHTML(for: url) {
            offlineHTML = cachedHTML
        }
    }

    func handleOfflineMode() {
        if !isNetworkAvailable() {
            if let currentURLString = currentURL?.absoluteString {
                loadOfflineContent(for: currentURLString)
            }
        }
    }

    func isNetworkAvailable() -> Bool {
        return true
    }

    func cacheResources(for html: String) {
        weo.saveCSS(html)
        weo.saveJavaScript(html)
        downloadAssets(from: html)
    }

    func replaceURLsWithLocalPaths(in html: String) -> String {
        var updatedHTML = html
        let patterns = [
            ("<link rel=[\"']stylesheet[\"'] href=[\"'](.*?)[\"'][^>]*>", "local://"),
            ("<script src=[\"'](.*?)[\"'][^>]*></script>", "local://"),
            ("src=[\"'](http[s]?://[^\"']+\\.(jpg|jpeg|png|gif))[\"']", "local://"),
            ("src=[\"'](http[s]?://[^\"']+\\.(mp4|mov|avi))[\"']", "local://")
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: html) {
                        let url = String(html[range])
                        updatedHTML = updatedHTML.replacingOccurrences(of: url, with: "\(replacement)\(url)")
                    }
                }
            }
        }
        return updatedHTML
    }

    func saveOfflinePage(for url: URL, html: String) {
        let localHTML = replaceURLsWithLocalPaths(in: html)
        weo.saveHTMLContent(url: url, html: localHTML)
    }

    func loadURLRequest(_ request: URLRequest) {
        if let webView = webView {
            webView.load(request)
        }
    }

    func configureWebView(_ webView: WKWebView) {
        self.webView = webView
        self.webView?.navigationDelegate = WebViewCoordinator(viewModel: self)
    }

    class WebViewCoordinator: NSObject, WKNavigationDelegate {
        var viewModel: BrowserViewModel

        init(viewModel: BrowserViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.saveCurrentPage(html: webView.html)
            viewModel.updateNavigationState(webView)
        }
    }

    func prefetchLinks(from html: String) {
        let linkPattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        if let regex = try? NSRegularExpression(pattern: linkPattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let url = String(html[range])
                    _ = weo.downloadContent(from: url)
                }
            }
        }
    }

    func cacheAndPrefetch(for html: String) {
        cacheResources(for: html)
        prefetchLinks(from: html)
    }

    func saveAndOptimizeOfflinePage(for url: URL, html: String) {
        let optimizedHTML = replaceURLsWithLocalPaths(in: html)
        saveOfflinePage(for: url, html: optimizedHTML)
    }

    func loadOfflinePageIfNeeded(for url: URL) {
        if !isNetworkAvailable() {
            loadOfflineContent(for: url.absoluteString)
        }
    }

    func prefetchAndCacheContent(for url: URL) {
        if let html = weo.loadCachedHTML(for: url.absoluteString) {
            cacheAndPrefetch(for: html)
        }
    }

    func handleNetworkChange() {
        if isNetworkAvailable() {
            if let url = currentURL {
                loadURLRequest(URLRequest(url: url))
            }
        } else {
            if let currentURLString = currentURL?.absoluteString {
                loadOfflineContent(for: currentURLString)
            }
        }
    }

    func setupWebView(_ webView: WKWebView) {
        self.webView = webView
        self.webView?.navigationDelegate = WebViewCoordinator(viewModel: self)
    }

    func loadInitialPage() {
        if let url = URL(string: urlString) {
            currentURL = url
            loadURLRequest(URLRequest(url: url))
        }
    }

    func savePageMetadata(for url: URL) {
        let metadata = ["url": url.absoluteString, "title": urlString]
        if let data = try? JSONSerialization.data(withJSONObject: metadata, options: []) {
            weo.saveData(data, forKey: url.absoluteString)
        }
    }

    func loadPageMetadata(for url: URL) -> [String: Any]? {
        if let data = weo.loadData(forKey: url.absoluteString) {
            return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
        }
        return nil
    }

    func cacheMediaFiles(from html: String) {
        let mediaPattern = "src=[\"'](http[s]?://[^\"']+\\.(mp3|wav|ogg|mp4|mkv))[\"']"
        downloadContent(withPattern: mediaPattern, from: html)
    }

    func saveUserPreferences() {
        let preferences = ["theme": "dark", "fontSize": "16px"]
        if let data = try? JSONSerialization.data(withJSONObject: preferences, options: []) {
            weo.saveData(data, forKey: "userPreferences")
        }
    }

    func loadUserPreferences() -> [String: Any]? {
        if let data = weo.loadData(forKey: "userPreferences") {
            return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
        }
        return nil
    }

    func saveCookies() {
        let cookies = HTTPCookieStorage.shared.cookies
        let cookieData = cookies?.map { cookie in
            return ["name": cookie.name, "value": cookie.value, "domain": cookie.domain, "path": cookie.path]
        }
        if let data = try? JSONSerialization.data(withJSONObject: cookieData as Any, options: []) {
            weo.saveData(data, forKey: "cookies")
        }
    }

    func loadCookies() {
        if let data = weo.loadData(forKey: "cookies"),
           let cookieArray = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]] {
            for cookieDict in cookieArray {
                var properties = [HTTPCookiePropertyKey: Any]()
                properties[.name] = cookieDict["name"]
                properties[.value] = cookieDict["value"]
                properties[.domain] = cookieDict["domain"]
                properties[.path] = cookieDict["path"]
                if let cookie = HTTPCookie(properties: properties) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        }
    }

    func enableOfflineMode() {
        handleOfflineMode()
    }

    func synchronizeData() {
        saveUserPreferences()
        saveCookies()
    }

    func restoreData() {
        loadUserPreferences()
        loadCookies()
    }

    func exportSavedPages() -> Data? {
        let savedPagesData = savedPages.map { ["url": $0] }
        return try? JSONSerialization.data(withJSONObject: savedPagesData, options: [])
    }

    func importSavedPages(from data: Data) {
        if let savedPagesArray = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]] {
            savedPages = savedPagesArray.compactMap { $0["url"] as? String }
        }
    }

    func optimizeOfflineData() {
        savedPages.forEach { loadOfflineContent(for: $0) }
    }

    func saveUserData() {
        let userData = ["username": "user", "password": "pass"]
        if let data = try? JSONSerialization.data(withJSONObject: userData, options: []) {
            weo.saveData(data, forKey: "userData")
        }
    }

    func loadUserData() -> [String: Any]? {
        if let data = weo.loadData(forKey: "userData") {
            return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
        }
        return nil
    }

    func clearUserData() {
        weo.deleteData(forKey: "userData")
    }

    func saveLoginState() {
        let loginState = ["isLoggedIn": true]
        if let data = try? JSONSerialization.data(withJSONObject: loginState, options: []) {
            weo.saveData(data, forKey: "loginState")
        }
    }

    func loadLoginState() -> [String: Any]? {
        if let data = weo.loadData(forKey: "loginState") {
            return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
        }
        return nil
    }

    func saveFormData() {
        let formData = ["field1": "value1", "field2": "value2"]
        if let data = try? JSONSerialization.data(withJSONObject: formData, options: []) {
            weo.saveData(data, forKey: "formData")
        }
    }

    func loadFormData() -> [String: Any]? {
        if let data = weo.loadData(forKey: "formData") {
            return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
        }
        return nil
    }

    func restoreUserData() {
        loadUserData()
        loadLoginState()
        loadFormData()
    }
}
```
