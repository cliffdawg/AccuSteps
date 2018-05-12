//
//  WatchSessionManager.swift
//  AccuSteps
//
//  Created by Clifford Yin on 6/26/17.
//  Copyright © 2017 Stanford University HCI. All rights reserved.
//


import Foundation
import WatchConnectivity

/* This class handles communication with the iPhone */
class WatchSessionManager: NSObject, WCSessionDelegate {
    
    static let sharedManager = WatchSessionManager()
    private override init() {
        super.init()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?){
        
    }
    
    private let session: WCSession = WCSession.default()
    
    func startSession(completion: @escaping (_ success: Bool) -> Void) {
        session.delegate = self
        session.activate()
        completion(true)

    }
    
    private var validSession: WCSession? {
        
        // paired - the user has to have their device paired to the watch
        // watchAppInstalled - the user must have your watch app installed
        
        // Note: if the device is paired, but your watch app is not installed
        // consider prompting the user to install it for a better experience
        
        let session = self.session
        if (session.isReachable) {
            return session
        }
        return nil
    }
    
    // Delivers message to iPhone
    func transferUserInfo(userInfo: [String : AnyObject]) -> WCSessionUserInfoTransfer? {
        return validSession?.transferUserInfo(userInfo)
    }
    
    // Sends a message to the phone and receives a response back
    func sendMessage(message: [String : Any] = [:], completion: @escaping (_ success: Bool) -> Void) {
        validSession?.sendMessage(message, replyHandler: { reply in
            
            // If no data, end it
            if (reply["none"] != nil){
               
                completion(true)
            
            // If data is returned, save them in the Watch
            } else {
                
            if (reply["returnID"] != nil) {
                UserDefaults.standard.set(reply["returnID"], forKey: "User ID")
              
                if (reply["steps"] != nil) {
                    
                    UserDefaults.standard.set(reply["steps"], forKey: "stepCount")
                    completion(true)
                } else {
                    
                    completion(true)
                }
                if (reply["date"] != nil) {
              
                    let dated = Date.init(timeIntervalSince1970: Double(reply["date"] as! String)!)
                    UserDefaults.standard.set(dated, forKey: "startDate")
                    completion(true)
                    
                } else {
                    completion(true)
                }
            }
            
                    }
        }, errorHandler: { error in
            print("error: \(error)")
            completion(true)
        })
        
    }

    // Sends a message to the iPhone and receives no response back
    func message(message: [String : Any] = [:], completion: @escaping (_ success: Bool) -> Void) {
        validSession?.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("message error: \(error)")
            completion(true)
        })
        completion(true)
    }

    // Receives data from the iPhone
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("DATA TRANSFERRED TO Watch")
        guard let userID = userInfo["userID"] as? NSString else {return}
        UserDefaults.standard.set(userID, forKey: "User ID")
        print(UserDefaults.standard.object(forKey: "User ID")!)
           }
}

