import Foundation
import Network

final class LocalHTTPServer {
    private let queue = DispatchQueue(label: "VideoBatchDownloader.LocalHTTPServer")
    private let onEnqueue: ([EnqueueItem]) -> Void
    private let onPreferences: (PreferencesUpdate) -> Void
    private var listener: NWListener?

    init(onEnqueue: @escaping ([EnqueueItem]) -> Void, onPreferences: @escaping (PreferencesUpdate) -> Void) {
        self.onEnqueue = onEnqueue
        self.onPreferences = onPreferences
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: 17832)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
        listener.start(queue: queue)
        self.listener = listener
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, accumulated: Data())
    }

    private func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var requestData = accumulated
            if let data { requestData.append(data) }

            if self.requestIsComplete(requestData) || isComplete || error != nil {
                self.respond(to: requestData, on: connection)
            } else {
                self.receive(on: connection, accumulated: requestData)
            }
        }
    }

    private func requestIsComplete(_ data: Data) -> Bool {
        guard let marker = data.range(of: Data("\r\n\r\n".utf8)) else { return false }
        let headerData = data[..<marker.lowerBound]
        let headers = String(decoding: headerData, as: UTF8.self)
        let contentLength = headers.split(separator: "\n")
            .first(where: { $0.lowercased().hasPrefix("content-length:") })
            .flatMap { Int($0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") }
            ?? 0
        return data.count >= marker.upperBound + contentLength
    }

    private func respond(to data: Data, on connection: NWConnection) {
        guard let marker = data.range(of: Data("\r\n\r\n".utf8)) else {
            send(status: "400 Bad Request", json: ["error": "Invalid request"], origin: nil, on: connection)
            return
        }

        let header = String(decoding: data[..<marker.lowerBound], as: UTF8.self)
        let origin = header.components(separatedBy: "\r\n")
            .first(where: { $0.lowercased().hasPrefix("origin:") })
            .map { String($0.dropFirst("origin:".count)).trimmingCharacters(in: .whitespacesAndNewlines) }
        let requestLine = header.components(separatedBy: "\r\n").first ?? ""
        let parts = requestLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let path = parts.count > 1 ? String(parts[1]) : ""

        guard LocalAPIOriginPolicy.isAllowed(origin) else {
            send(status: "403 Forbidden", json: ["error": "Origin not allowed"], origin: nil, on: connection)
            return
        }

        if method == "OPTIONS" {
            send(status: "204 No Content", body: Data(), origin: origin, on: connection)
        } else if method == "GET", path == "/health" {
            send(status: "200 OK", json: ["status": "ready", "app": "VidSavie"], origin: origin, on: connection)
        } else if method == "GET", path == "/preferences" {
            send(status: "200 OK", json: AppPreferences.response, origin: origin, on: connection)
        } else if method == "POST", path == "/preferences" {
            let body = data[marker.upperBound...]
            do {
                let update = try JSONDecoder().decode(PreferencesUpdate.self, from: body)
                AppPreferences.apply(update)
                onPreferences(update)
                send(status: "200 OK", json: AppPreferences.response, origin: origin, on: connection)
            } catch {
                send(status: "400 Bad Request", json: ["error": "Invalid preferences"], origin: origin, on: connection)
            }
        } else if method == "POST", path == "/enqueue" {
            let body = data[marker.upperBound...]
            do {
                let request = try JSONDecoder().decode(EnqueueRequest.self, from: body)
                let supported = request.items.filter { URLNormalizer.isSupported(URLNormalizer.normalize($0.url)) }
                onEnqueue(supported)
                send(status: "202 Accepted", json: ["accepted": supported.count, "total": request.items.count], origin: origin, on: connection)
            } catch {
                send(status: "400 Bad Request", json: ["error": "Expected JSON: {\"urls\":[\"https://…\"]}"], origin: origin, on: connection)
            }
        } else {
            send(status: "404 Not Found", json: ["error": "Not found"], origin: origin, on: connection)
        }
    }

    private func send(status: String, json: [String: Any], origin: String?, on connection: NWConnection) {
        let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data("{}".utf8)
        send(status: status, body: data, origin: origin, on: connection)
    }

    private func send(status: String, body: Data, origin: String?, on connection: NWConnection) {
        let cors = LocalAPIOriginPolicy.corsValue(for: origin)
            .map { "Access-Control-Allow-Origin: \($0)\r\nVary: Origin\r\n" }
            ?? ""
        let header = "HTTP/1.1 \(status)\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(body.count)\r\n\(cors)Access-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}
