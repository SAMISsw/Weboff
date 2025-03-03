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
import Network
import AVKit
import AVFoundation

extension String {
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

struct ContentView: View {
    @StateObject private var viewModel = BrowserViewModel()
    @State private var showNewWindow = false
    @State private var currentPageTitle: String = ""
    
    var body: some View {
        VStack {
            Text("WEO")
                .font(.custom("Impact", size: 40))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            
            HStack {
                TextField("Digite a URL ou pesquisa", text: $viewModel.urlString, onCommit: { viewModel.loadURL() })
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .frame(minHeight: 50)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)

                Button(action: viewModel.goBack) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .disabled(!viewModel.canGoBack)
                .padding()

                Button(action: viewModel.goForward) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .disabled(!viewModel.canGoForward)
                .padding()
            }

            ScrollView(.horizontal) {
                HStack {
                    ForEach(viewModel.openWindows, id: \.id) { window in
                        Button(action: {
                            viewModel.switchToWindow(window)
                        }) {
                            Text(window.title)
                                .foregroundColor(.blue)
                                .padding()
                        }
                    }
                }
            }
            
            WebView(viewModel: viewModel, currentPageTitle: $currentPageTitle)
                .frame(maxHeight: .infinity)

            HStack {
                Button(action: { showNewWindow.toggle() }) {
                    Image(systemName: "app.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .padding()

                Button(action: { viewModel.savePage() }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title)
                        .foregroundColor(.white)
                }

                Button(action: { viewModel.saveMedia() }) {
                    Image(systemName: "photo.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .padding()
            
            if showNewWindow {
                WindowView(showWindow: $showNewWindow, currentPageTitle: currentPageTitle)
            }
        }
        .background(Color.blue)
        .cornerRadius(20)
        .padding()
        .onAppear {
            viewModel.loadGoogleSearch()
        }
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    @Binding var currentPageTitle: String

    func makeUIView(context: Context) -> WKWebView {
        let webview = WKWebView()
        webview.navigationDelegate = context.coordinator
        return webview
    }

    func updateUIView(_ webview: WKWebView, context: Context) {
        if viewModel.isOnline {
            if let url = viewModel.currentURL {
                webview.load(URLRequest(url: url))
            }
        } else {
            webview.loadHTMLString(viewModel.offlineHTML, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(viewModel: viewModel, currentPageTitle: $currentPageTitle)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var viewModel: BrowserViewModel
        @Binding var currentPageTitle: String

        init(viewModel: BrowserViewModel, currentPageTitle: Binding<String>) {
            self.viewModel = viewModel
            self._currentPageTitle = currentPageTitle
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.title") { title, _ in
                if let pageTitle = title as? String {
                    self.currentPageTitle = pageTitle
                }
            }

            viewModel.updateNavigationState(webView)
        }
    }
}

struct WindowView: View {
    @Binding var showWindow: Bool
    var currentPageTitle: String

    var body: some View {
        VStack {
            Text("\(currentPageTitle)")
                .font(.subheadline)
                .padding()

            Button(action: {
                showWindow = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.red)
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(15)
        .frame(width: 300, height: 300)
        .shadow(radius: 10)
        .padding()
    }
}

class BrowserViewModel: ObservableObject {
    @Published var currentURL: URL?
    @Published var urlString: String = ""
    @Published var offlineHTML: String = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isOnline: Bool = true
    @Published var savedPages = [String: String]()
    @Published var mediaFiles = [String: MediaData]()
    @Published var openWindows: [BrowserWindow] = []
    @Published var navigationHistory: [String] = []
    @Published var userSettings: [String: Any] = [:]
    @Published var userData: [String: String] = [:]

    private var webView: WKWebView?
    private var monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isOnline = path.status == .satisfied
            }
        }
        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }

    func loadURL() {
        if isValidURL(urlString) {
            if let url = URL(string: urlString) {
                currentURL = url
                addWindow(withTitle: "Página \(urlString)")
            }
        } else {
            performGoogleSearch(query: urlString)
        }
    }

    func isValidURL(_ string: String) -> Bool {
        return string.lowercased().hasPrefix("http://") || string.lowercased().hasPrefix("https://")
    }

    func performGoogleSearch(query: String) {
        let searchQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let googleURL = "https://www.google.com/search?q=\(searchQuery)"
        if let url = URL(string: googleURL) {
            currentURL = url
            addWindow(withTitle: "Busca Google")
        }
    }

    func loadGoogleSearch() {
        urlString = "https://www.google.com"
        loadURL()
    }

    func addWindow(withTitle title: String) {
        let window = BrowserWindow(title: title, url: currentURL ?? URL(string: "https://www.google.com")!)
        openWindows.append(window)
        navigationHistory.append(title)
        saveNavigationHistory()
    }

    func switchToWindow(_ window: BrowserWindow) {
        currentURL = window.url
    }

    func savePage() {
        guard let currentURL = currentURL else { return }
        UserDefaults.standard.set(offlineHTML, forKey: currentURL.absoluteString)
    }

    func saveMedia() {
        webView?.evaluateJavaScript("""
            var media = document.querySelectorAll('video, audio, img, source');
            var mediaArray = [];
            media.forEach(function(item) {
                if (item.src) mediaArray.push(item.src);
            });
            return mediaArray;
        """) { (media, _) in
            if let mediaArray = media as? [String] {
                self.downloadAndSaveMedia(mediaArray)
            }
        }
    }

    func downloadAndSaveMedia(_ mediaArray: [String]) {
        for media in mediaArray {
            if let url = URL(string: media) {
                downloadFile(from: url) { success in
                    if success {
                        let fileName = url.lastPathComponent
                        let mediaData = MediaData(fileName: fileName, filePath: self.getDocumentsDirectory().appendingPathComponent(fileName).path)
                        self.mediaFiles[fileName] = mediaData
                    }
                }
            }
        }
    }

    func downloadFile(from url: URL, completion: @escaping (Bool) -> Void) {
        let downloadTask = URLSession.shared.downloadTask(with: url) { (url, response, error) in
            guard let url = url, error == nil else {
                completion(false)
                return
            }

            do {
                let destinationURL = self.getDocumentsDirectory().appendingPathComponent(url.lastPathComponent)
                try FileManager.default.moveItem(at: url, to: destinationURL)
                completion(true)
            } catch {
                completion(false)
            }
        }
        downloadTask.resume()
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func updateNavigationState(_ webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func saveNavigationHistory() {
        UserDefaults.standard.set(navigationHistory, forKey: "navigationHistory")
    }

    func loadUserData() {
        if let storedData = UserDefaults.standard.dictionary(forKey: "userData") {
            userData = storedData as? [String: String] ?? [:]
        }
    }
}

struct BrowserWindow: Identifiable {
    var id = UUID()
    var title: String
    var url: URL
}

struct MediaData {
    var fileName: String
    var filePath: String
}
```
