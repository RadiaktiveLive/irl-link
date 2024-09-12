import Foundation
import WatchConnectivity

struct Message: Identifiable, Hashable {
    let id = UUID()
    let username: String
    let message: String
    let color: String
    let badges: Array<String>
}

class WatchViewModel: NSObject, ObservableObject {
    var session: WCSession
    @Published var messages: [Message] = []
    @Published var viewers: Int = 0
    @Published var isLive: Bool = false
    
    // Add more cases if you have more receive method
    enum WatchReceiveMethod: String {
        case sendChatMessageToNative
    }
    
    // Add more cases if you have more sending method
    enum WatchSendMethod: String {
        case sendCounterToFlutter
    }
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        self.session.delegate = self
        session.activate()
    }
    
    func sendDataMessage(for method: WatchSendMethod, data: [String: Any] = [:]) {
        sendMessage(for: method.rawValue, data: data)
    }
    
}

extension WatchViewModel: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    // Receive message From AppDelegate.swift that send from iOS devices
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            print("receiving")
            guard let method = message["method"] as? String, let enumMethod = WatchReceiveMethod(rawValue: method) else {
                return
            }
            
            switch enumMethod {
            case .sendChatMessageToNative:
                self.messages.append(message["data"] as? Message ?? Message(username: "error", message: "wrong data type received", color: "#FFFFFF", badges: []))
                if(self.messages.count > 10) {
                    self.messages.removeFirst()
                }
            }
        }
    }
    
    func sendMessage(for method: String, data: [String: Any] = [:]) {
        guard session.isReachable else {
            print("ios not reachable")
            return
        }
        let messageData: [String: Any] = ["method": method, "data": data]
        print("sending data to ios")
        session.sendMessage(messageData, replyHandler: nil, errorHandler: nil)
    }
    
}
