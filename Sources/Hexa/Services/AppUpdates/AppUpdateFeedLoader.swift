// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import Foundation

/// A short-lived metadata request. The session retains its delegate until
/// completion, then invalidates; no session or observer survives the check.
final class AppUpdateFeedLoader: NSObject, URLSessionDataDelegate {
    private var data = Data()
    private var accepted = false
    private var redirects = 0
    /// Set from the task metrics, which arrive before completion.
    private var peersArePublic = false
    private var result: AppUpdateFeedSupport.LoadResult = .failed
    private let resolve: AppUpdateFeedAddressGuard.Resolver
    private let completion: (AppUpdateFeedSupport.LoadResult) -> Void

    private init(resolve: @escaping AppUpdateFeedAddressGuard.Resolver,
                 completion: @escaping (AppUpdateFeedSupport.LoadResult) -> Void) {
        self.resolve = resolve
        self.completion = completion
    }

    static func load(_ url: URL, completion: @escaping (AppUpdateFeedSupport.LoadResult) -> Void) {
        load(url, resolve: AppUpdateFeedAddressGuard.systemAddresses,
             configuration: productionConfiguration(), completion: completion)
    }

    /// Ephemeral session settings for feed reads: no cache, cookies or credentials.
    static func productionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.urlCredentialStorage = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }

    /// The feed host must resolve to public addresses before any request starts.
    /// The peer the session really connected to is checked again at the end:
    /// feeds are HTTPS only, so a host rebound to an internal address fails the
    /// certificate check before any request is sent, and an answer from a
    /// non-public peer is never used.
    static func load(_ url: URL, resolve: @escaping AppUpdateFeedAddressGuard.Resolver,
                     configuration: URLSessionConfiguration,
                     completion: @escaping (AppUpdateFeedSupport.LoadResult) -> Void) {
        guard AppUpdateFeedSupport.publicURL(url.absoluteString) != nil, let host = url.host else {
            completion(.failed)
            return
        }
        DispatchQueue.global(qos: .utility).async {
            guard AppUpdateFeedAddressGuard.allowsHost(host, resolve: resolve) else {
                completion(.failed)
                return
            }
            let delegate = AppUpdateFeedLoader(resolve: resolve, completion: completion)
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            session.dataTask(with: url).resume()
            session.finishTasksAndInvalidate()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        if AppUpdateFeedSupport.feedIsAbsent(statusCode: statusCode) {
            accepted = false
            result = .absent
            completionHandler(.cancel)
            return
        }
        accepted = statusCode.map { (200..<300).contains($0) } == true
            && response.expectedContentLength <= Int64(AppUpdateFeedSupport.byteLimit)
        completionHandler(accepted ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        guard accepted, chunk.count <= AppUpdateFeedSupport.byteLimit - data.count else {
            accepted = false
            dataTask.cancel()
            return
        }
        data.append(chunk)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        redirects += 1
        guard redirects <= 5, let url = request.url,
              AppUpdateFeedSupport.publicURL(url.absoluteString) != nil,
              let host = url.host, AppUpdateFeedAddressGuard.allowsHost(host, resolve: resolve) else {
            completionHandler(nil)
            return
        }
        completionHandler(URLRequest(url: url))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        peersArePublic = AppUpdateFeedAddressGuard.connectedPeersArePublic(metrics)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard peersArePublic else {
            completion(.failed)
            return
        }
        completion(error == nil && accepted ? .data(data) : result)
    }
}
