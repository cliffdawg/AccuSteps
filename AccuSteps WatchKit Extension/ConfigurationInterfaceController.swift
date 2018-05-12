//
//  ConfigurationInterfaceController.swift
//  AccuSteps
//
//  Created by Clifford Yin on 6/27/17.
//  Copyright © 2017 Stanford University HCI. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit
import UserNotifications
import WatchConnectivity

/* Code for the Watch app configuration interface controller */
class ConfigurationInterfaceController: WKInterfaceController, WCSessionDelegate {
    
    // MARK: IBOutlets
    
    @IBOutlet var ParticipantNumberLabel: WKInterfaceLabel!
    
    @IBOutlet var startButton: WKInterfaceButton!
    
    // MARK: Initialization
    
    var loadingSteps = true
    var fromWatching = true
    var sessioning = true
    var tapping = true
    var sessionTwo = true
    
    private let session: WCSession = WCSession.default()
    
    override init() {
        print("init")
        super.init()
    }
    
    // If linking with the iPhone fails, it will repeatedly attempt until it succeeds
    func startSession() {
        if (self.sessioning == true) {
            
        session.delegate = self
        session.activate()
            
        let when = DispatchTime.now() + 5
        DispatchQueue.main.asyncAfter(deadline: when) {
            
            if (self.sessionTwo == true) {
            self.startSession()
    
                }
            }
        }
        
    }

    // MARK: Interface Controller Overrides
    override func willActivate() {
        self.startSession()
        print("willActivate")

    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        print("awake")
        }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?){
        
        self.fromWatch()
        self.sessioning = false
        self.sessionTwo = false
     
    }
    
    override func didAppear() {
        
        super.didAppear()
 
    }
    
    // Checks phone for participant ID and stepCount
    func fromWatch() {
        
        let toCheck = ["fromWatch" : "checkID"]
        WatchSessionManager.sharedManager.sendMessage(message: toCheck) { (success) -> Void in
            if success {
                self.fromWatching = false
                self.loadSteps()
            }
            else {
                
                self.loadSteps()
            }
        }
    }
    
    // If the participant ID and heartLastDate is present, then the app will proceed to the home interface controller; if not, then it will prompt the user to enter the info
    func loadSteps(){

        WatchSessionManager.sharedManager.startSession() { (success) -> Void in
            if success {
                
                self.loadingSteps = false
                let participantNumber = UserDefaults.standard.string(forKey: "User ID")
    
                if (participantNumber != nil)
                {
                    if (UserDefaults.standard.object(forKey: "heartLastDate") == nil) {
                        UserDefaults.standard.set(Date(), forKey: "heartLastDate")
                    }

                    self.ParticipantNumberLabel.setText(participantNumber)
                    let workoutConfiguration = HKWorkoutConfiguration()
                    WKInterfaceController.reloadRootControllers(withNames: ["StepsInterfaceController"], contexts: [workoutConfiguration])
                }
                else
                {
                    self.ParticipantNumberLabel.setText("AccuSteps")
                    self.startButton.setAlpha(1.0)
                }

            } else {
              
                let participantNumber = UserDefaults.standard.string(forKey: "User ID")
         
                if (participantNumber != nil)
                {
         
                    if (UserDefaults.standard.object(forKey: "heartLastDate") == nil) {
                        UserDefaults.standard.set(Date(), forKey: "heartLastDate")
                    }

                    self.ParticipantNumberLabel.setText(participantNumber)
                    let workoutConfiguration = HKWorkoutConfiguration()
                    WKInterfaceController.reloadRootControllers(withNames: ["StepsInterfaceController"], contexts: [workoutConfiguration])
                }
                else
                {
                    self.ParticipantNumberLabel.setText("AccuSteps")
                    self.startButton.setAlpha(1.0)
                }

            }
        }
        
        // These methods are to ensure that if the app gets stuck, it will continue onto the configuration controller or home controller after a certain time
        let when = DispatchTime.now() + 15
        DispatchQueue.main.asyncAfter(deadline: when) {
            if (self.loadingSteps) {
                
                let participantNumber = UserDefaults.standard.string(forKey: "User ID")
                if (participantNumber != nil)
            {
                if (UserDefaults.standard.object(forKey: "heartLastDate") == nil) {
                    UserDefaults.standard.set(Date(), forKey: "heartLastDate")
                }

                self.ParticipantNumberLabel.setText(participantNumber)
                let workoutConfiguration = HKWorkoutConfiguration()
                WKInterfaceController.reloadRootControllers(withNames: ["StepsInterfaceController"], contexts: [workoutConfiguration])
            }
            else
            {
                self.ParticipantNumberLabel.setText("AccuSteps")
                self.startButton.setAlpha(1.0)
                }
            }
        }
    }
    
    private func requestAccessToHealthKit() {
        let healthStore = HKHealthStore()
        
        let allTypes = Set([HKObjectType.workoutType(),
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.flightsClimbed)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.basalEnergyBurned)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.appleExerciseTime)!])
        
        let allTypes1 = Set([HKObjectType.workoutType(),
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.flightsClimbed)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling)!,
                            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.basalEnergyBurned)!])
        
        healthStore.requestAuthorization(toShare: allTypes1, read: allTypes) { (success, error) in
            if !success {
                print(error ?? "Error occurred requesting access to HealthKit")
            }
        }
    }
    
    private func requestAllowNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if !granted {
                print(error ?? "Error occurred requesting notifications")
            }
        }
    }
    
    // When the button is tapped, it checks if the Watch has a participant ID
    func checkID() {
        let participantNumber = UserDefaults.standard.string(forKey: "User ID")
        if (participantNumber != nil) {
    
            if (UserDefaults.standard.object(forKey: "heartLastDate") == nil) {
                UserDefaults.standard.set(Date(), forKey: "heartLastDate")
            }
                UserDefaults.standard.set("0", forKey: "stepCount")
            
            UserDefaults.standard.set("0", forKey: "notifyCounter")
            
            // If there is no participant ID, check the iPhone for one
            let toPhone = ["setting":"0"]
            WatchSessionManager.sharedManager.message(message: toPhone) { (success) -> Void in
                if success {
                    
                    self.requestAccessToHealthKit()
                    self.requestAllowNotifications()
                    WKInterfaceController.reloadRootControllers(withNames: ["StepsInterfaceController"], contexts: nil)
                }
            }
           
        // If no participant ID, then it flashes red and prompts for it on the iPhone
        } else {
            
            self.ParticipantNumberLabel.setTextColor(UIColor.red)
            self.ParticipantNumberLabel.setText("Enter participant info on the phone!")
            let when = DispatchTime.now() + 2
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.ParticipantNumberLabel.setTextColor(UIColor.init(red: 252/255, green: 208/255, blue: 62/255, alpha: 1.0))
                self.ParticipantNumberLabel.setText("AccuSteps")
            }
        }

    }
    
    // MARK: IB Actions
    
        @IBAction func didTapStartButton() {
            let toCheck = ["fromWatch" : "checkID"]
            WatchSessionManager.sharedManager.sendMessage(message: toCheck) { (success) -> Void in
                if success {
                    
                    self.tapping = false
                    self.checkID()
                    
                } else {

                    self.checkID()
                }
            }
        }
    
    // Deliver message to iPhone that asks for participant iD
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let userID = userInfo["userID"] as? NSString else {return}
        UserDefaults.standard.set(userID, forKey: "User ID")
        print(UserDefaults.standard.object(forKey: "User ID")!)
    }
    
}
