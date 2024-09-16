import Foundation
import WatchConnectivity

struct ObsSource: Hashable {
    var sceneItemId: Int
    var sceneItemEnabled: Bool
    var sourceName: String
}

class WatchViewModel: NSObject, ObservableObject {
    var session: WCSession
    @Published var messages: [Message] = []
    @Published var viewers: Int = 0
    @Published var isLive: Bool = false
    
    @Published var obsConnected: Bool = false
    @Published var selectedScene: String = ""
    @Published var scenes: [String] = []
    @Published var sources: [ObsSource] = []
    
    // Add more cases if you have more receive method
    enum WatchReceiveMethod: String {
        case sendChatMessageToNative
        case sendViewersToNative
        case sendLiveStatusToNative
        case sendUpdateObsConnecteToNative
        case sendSelectedObsSceneToNative
        case sendObsScenesToNative
        case sendObsSourcesToNative
    }
    
    // Add more cases if you have more sending method
    enum WatchSendMethod: String {
        case sendChangeObsSceneToFlutter
        case sendToggleObsSourceToFlutter
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
            guard let method = message["method"] as? String, let enumMethod = WatchReceiveMethod(rawValue: method) else {
                return
            }
            
            switch enumMethod {
            case .sendChatMessageToNative:
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: message["data"]!, options: [])
                    do {
                        let msg = try JSONDecoder().decode(Message.self, from: jsonData)
                        self.messages.append(msg)
                        if(self.messages.count > 10) {
                            self.messages.removeFirst()
                        }
                    } catch {
                        // Handle error
                        print("Error occurred: \(error)")
                    }
                } catch {
                    // Handle error
                    print("Error occurred: \(error)")
                }
            case .sendViewersToNative:
                self.viewers = message["data"] as! Int
            case .sendLiveStatusToNative:
                self.isLive = message["data"] as! Bool
            case .sendUpdateObsConnecteToNative:
                self.obsConnected = message["data"] as! Bool
            case .sendSelectedObsSceneToNative:
                self.selectedScene = message["data"] as! String
            case .sendObsScenesToNative:
                self.scenes = message["data"] as! [String]
            case .sendObsSourcesToNative:
                print(message["data"]!)
                self.sources = message["data"] as! [ObsSource]
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
