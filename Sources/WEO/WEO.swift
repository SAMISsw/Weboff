import Foundation

@available(iOS 13.0, *)
public class WEO {
    private let cacheDirectory: URL?
    
    public init() {
        cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    @available(iOS 13.0, *)
    public func updateLinksToLocal(_ html: String) -> String {
        let pattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let link = String(html[range])
                    if let cachedContent = retrieveFromCache(for: link) {
                        updatedHTML = updatedHTML.replacingOccurrences(of: link, with: "local://\(link)")
                    }
                }
            }
        }
        return updatedHTML
    }
    
    @available(iOS 13.0, *)
    public func deepHTMLScan(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard url.scheme == "https" else {
            completion(.failure(NSError(domain: "WeboffError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Apenas URLs HTTPS são permitidas."])))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "WeboffError", code: 402, userInfo: [NSLocalizedDescriptionKey: "Erro ao converter dados para string."])))
                return
            }
            
            let updatedHTML = self.updateLinksToLocal(htmlString)
            completion(.success(updatedHTML))
        }.resume()
    }
    
    @available(iOS 13.0, *)
    public func startTracking(url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        deepHTMLScan(url: url) { result in
            switch result {
            case .success(let html):
                let links = self.extractLinks(from: html)
                self.trackLinks(links: links, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func extractLinks(from html: String) -> [URL] {
        let pattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        var links = [URL]()
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html),
                   let url = URL(string: String(html[range])) {
                    links.append(url)
                }
            }
        }
        return links
    }
    
    @available(iOS 13.0, *)
    private func trackLinks(links: [URL], completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        
        for link in links {
            group.enter()
            deepHTMLScan(url: link) { result in
                switch result {
                case .success(let html):
                    self.saveHTMLContent(url: link, html: html)
                    self.saveCSS(html: html)
                    self.saveJavaScript(html: html)
                    self.downloadImages(from: html)
                    self.downloadVideos(from: html) 
                    let nestedLinks = self.extractLinks(from: html)
                    self.trackLinks(links: nestedLinks, completion: { _ in })
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(.success(()))
            } else {
                NotificationCenter.default.post(name: Notification.Name("TrackingError"), object: errors)
                completion(.failure(NSError(domain: "WeboffError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Erros durante o rastreamento: \(errors)"])))
            }
        }
    }
    
    @available(iOS 13.0, *)
    public func connectSavedPages(html: String) -> String {
        let pattern = "href=[\"'](.*?)[\"']"
        var connectedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let link = String(html[range])
                    if let cachedPage = retrieveFromCache(for: link) {
                        connectedHTML = connectedHTML.replacingOccurrences(of: link, with: "local://\(link)")
                    }
                }
            }
        }
        return connectedHTML
    }
    
    @available(iOS 13.0, *)
    public func retrievePageResources(from html: String) -> [String] {
        let pattern = "(http[s]?://[^\"' ]+\\.(css|png|jpg|gif|js))"
        var resources: [String] = []
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 0), in: html) {
                    resources.append(String(html[range]))
                }
            }
        }
        return resources
    }
    
    @available(iOS 13.0, *)
    private func retrieveFromCache(for url: String) -> String? {
        guard let cacheDir = cacheDirectory else { return nil }
        let filePath = cacheDir.appendingPathComponent(url.replacingOccurrences(of: "/", with: "_"))
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    @available(iOS 13.0, *)
    public func saveHTMLContent(url: URL, html: String) {
        guard let cacheDir = cacheDirectory else { return }
        let filePath = cacheDir.appendingPathComponent(url.lastPathComponent.replacingOccurrences(of: "/", with: "_"))
        do {
            try html.write(to: filePath, atomically: true, encoding: .utf8) 
        } catch {}
    }
    
    @available(iOS 13.0, *)
    public func loadHTMLContent(url: URL) -> String? {
        guard let cacheDir = cacheDirectory else { return nil }
        let filePath = cacheDir.appendingPathComponent(url.lastPathComponent.replacingOccurrences(of: "/", with: "_"))
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    @available(iOS 13.0, *)
    public func removeCachedPage(url: URL) {
        guard let cacheDir = cacheDirectory else { return }
        let filePath = cacheDir.appendingPathComponent(url.lastPathComponent.replacingOccurrences(of: "/", with: "_"))
        do {
            try FileManager.default.removeItem(at: filePath)
        } catch {}
    }
    
    @available(iOS 13.0, *)
    public func saveCSS(html: String) -> String {
        let pattern = "<link rel=[\"']stylesheet[\"'] href=[\"'](.*?)[\"'][^>]*>"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let cssLink = String(html[range])
                    if let cssContent = downloadContent(from: cssLink) {
                        saveCSSContent(content: cssContent, for: cssLink)
                        updatedHTML = updatedHTML.replacingOccurrences(of: cssLink, with: "local://\(cssLink)")
                    }
                }
            }
        }
        return updatedHTML
    }
    
    @available(iOS 13.0, *)
    public func saveJavaScript(html: String) -> String {
        let pattern = "<script src=[\"'](.*?)[\"'][^>]*></script>"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let jsLink = String(html[range])
                    if let jsContent = downloadContent(from: jsLink) {
                        saveJavaScriptContent(content: jsContent, for: jsLink)
                        updatedHTML = updatedHTML.replacingOccurrences(of: jsLink, with: "local://\(jsLink)")
                    }
                }
            }
        }
        return updatedHTML
    }
    
    private func downloadImages(from html: String) {
        let pattern = "src=[\"'](http[s]?://[^\"']+\\.(jpg|jpeg|png|gif))[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let imageLink = String(html[range])
                    _ = downloadContent(from: imageLink) 
                }
            }
        }
    }
    
    private func downloadVideos(from html: String) {
        let pattern = "src=[\"'](http[s]?://[^\"']+\\.(mp4|mov|avi))[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let videoLink = String(html[range])
                    _ = downloadContent(from: videoLink) 
                }
            }
        }
    }
    
    private func downloadContent(from url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        var content: String?
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let html = String(data: data, encoding: .utf8) {
                content = html
            }
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        return content
    }
    
    private func saveCSSContent(content: String, for url: String) {
         guard let cacheDir = cacheDirectory else { return }
        let filePath = cacheDir.appendingPathComponent(url.replacingOccurrences(of: "/", with: "_"))
        do {
            try content.write(to: filePath, atomically: true, encoding: .utf8)
        } catch {}
    }
    
    private func saveJavaScriptContent(content: String, for url: String) {
          guard let cacheDir = cacheDirectory else { return }
        let filePath = cacheDir.appendingPathComponent(url.replacingOccurrences(of: "/", with: "_"))
        do {
            try content.write(to: filePath, atomically: true, encoding: .utf8)
        } catch {}
    }
}
