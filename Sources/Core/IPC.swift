import Foundation

enum ControlIPC {
    static let portName = "com.justcallmebryan.gigi.control"
    static let messageID: Int32 = 1

    static func send(_ request: String, timeout: TimeInterval = 2.0) -> String? {
        guard let remote = CFMessagePortCreateRemote(nil, portName as CFString) else { return nil }
        defer { CFMessagePortInvalidate(remote) }
        let bytes = Array(request.utf8)
        guard let payload = CFDataCreate(nil, bytes, bytes.count) else { return nil }
        var reply: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(
            remote, messageID, payload, timeout, timeout,
            CFRunLoopMode.defaultMode.rawValue, &reply
        )
        guard status == kCFMessagePortSuccess, let data = reply?.takeRetainedValue() else { return nil }
        return String(data: data as Data, encoding: .utf8)
    }
}

final class ControlServer {
    var handler: ((String) -> String)?
    private var port: CFMessagePort?
    private var source: CFRunLoopSource?

    func start() -> Bool {
        let callback: CFMessagePortCallBack = { _, _, data, info in
            guard let info else { return nil }
            let server = Unmanaged<ControlServer>.fromOpaque(info).takeUnretainedValue()
            let request = data.map { String(decoding: $0 as Data, as: UTF8.self) } ?? "status"
            let response = server.handler?(request) ?? "error: no handler"
            let bytes = Array(response.utf8)
            guard let out = CFDataCreate(nil, bytes, bytes.count) else { return nil }
            return Unmanaged.passRetained(out)
        }
        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        guard let local = CFMessagePortCreateLocal(nil, ControlIPC.portName as CFString, callback, &context, nil) else {
            Log.error("IPC: cannot create local port \(ControlIPC.portName)")
            return false
        }
        port = local
        source = CFMessagePortCreateRunLoopSource(nil, local, 0)
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        Log.info("IPC: listening on \(ControlIPC.portName)")
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { CFMessagePortInvalidate(port) }
        source = nil
        port = nil
    }
}
