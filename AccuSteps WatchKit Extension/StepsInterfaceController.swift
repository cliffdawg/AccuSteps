//
//  StepsInterfaceController.swift
//  AccuSteps
//
//  Created by Clifford Yin on 6/27/17.
//  Copyright © 2017 Stanford University HCI. All rights reserved.
//


import WatchKit
import Foundation
import HealthKit
import ClockKit
import WatchConnectivity
import UserNotifications

/* Code for the Watch app home interface controller */
class StepsInterfaceController: WKInterfaceController, WKExtensionDelegate, UNUserNotificationCenterDelegate {
    // MARK: Properties
    
    let timeBetweenRefresh = 15.0 * 60.0
    
    let healthStore = HKHealthStore()
    
    var activeDataQueries = [HKQuery]()
    
    var running = false // This variable is what determines whether or not the step count label will update steps
    
    let stepType = 0 as AnyObject
    let heartType = 1 as AnyObject
    
    var totalStepCount = HKQuantity(unit: HKUnit.count(), doubleValue: 0)
    
    var session : WCSession!

    // MARK: IBOutlets
    @IBOutlet var modifiedStepCountLabel: WKInterfaceLabel!

    
    
    // MARK: Interface Controller Overrides
    
    override func awake(withContext context: Any?) {
        // This checks if a participant ID or lastDate for heart rate exists; if not, it opens up the Configuration interface controller
        if (((UserDefaults.standard.string(forKey: "User ID")) == nil) || (UserDefaults.standard.object(forKey: "heartLastDate") == nil)){
            
            let workoutConfiguration = WKInterfaceController()
            WKInterfaceController.reloadRootControllers(withNames: ["ConfigurationInterfaceController"], contexts: [workoutConfiguration])
        }
            
        // If it does exist, it continues on
        else {
            
            super.awake(withContext: context)
            print("awake")
            
            WKExtension.shared().delegate = self // Allows this class to handle background refreshes ('handle:' function)
            
            let when = DispatchTime.now() + 1.5
            DispatchQueue.main.asyncAfter(deadline: when) {
            
            let startDate = UserDefaults.standard.object(forKey: "startDate") as! Date
            if (UserDefaults.standard.object(forKey: "startDate") != nil) { // If there is a startDate, the step count label will update as normal
                
                if (startDate < Date()) {
                    
                    self.running = true
                    self.setTotalSteps(steps: self.modToActualSteps(modified: Double(UserDefaults.standard.string(forKey: "stepCount")!)!))
                    self.updateLabels()

                } else {
                    
                    self.running = false
                    self.setTotalSteps(steps: self.modToActualSteps(modified: Double(UserDefaults.standard.string(forKey: "stepCount")!)!))
                    self.updateLabels()


                }
            } else {
                
                // If there is no heart rate startDate, the Watch will try to retrieve from the iPhone
                let toCheck = ["fromWatch" : "checkID"]
                WatchSessionManager.sharedManager.sendMessage(message: toCheck) { (success) -> Void in
                    if success {
                        
                        if (startDate < Date()) {
                            self.running = true
                            self.setTotalSteps(steps: self.modToActualSteps(modified: Double(UserDefaults.standard.string(forKey: "stepCount")!)!))
                            self.updateLabels()

                        } else {
                            
                            self.running = false
                            self.setTotalSteps(steps: self.modToActualSteps(modified: Double(UserDefaults.standard.string(forKey: "stepCount")!)!))
                            self.updateLabels()

                        }

                    } else {
                        
                        UserDefaults.standard.set(Date(), forKey: "startDate")
                        self.setTotalSteps(steps: self.modToActualSteps(modified: Double(UserDefaults.standard.string(forKey: "stepCount")!)!))
                        self.updateLabels()

                    }
                }

            }
        
            let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)
            let authorizationStatus = self.healthStore.authorizationStatus(for: type!)
            switch authorizationStatus {
            
            // If sharing of health data is authorized, the step count refreshes each restart of the app
            case .sharingAuthorized:
                print("sharing authorized")
                self.refreshStepCount()
            case .sharingDenied:
                print("sharing denied")
            default:
                print("not determined")
                }
            }
        }
    }
    
    override func willActivate() {
        WatchSessionManager.sharedManager.startSession() { (success) -> Void in
            if success {
                // Do nothing
            }
        }

        // This prints out and checks if sharing of health data is authorized
        let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)
        let authorizationStatus = healthStore.authorizationStatus(for: type!)
        switch authorizationStatus {
        case .sharingAuthorized:
            print("sharing authorized")
        case .sharingDenied:
            print("sharing denied")
        default:
            print("not determined")
        }

        let future = Date(timeIntervalSinceNow: timeBetweenRefresh)

        scheduleBackgroundRefresh(preferredDate: future)
        let dateformatter = DateFormatter()
        dateformatter.dateStyle = .short
        dateformatter.timeStyle = .short
        print("Scheduling background task from willActivate: " + dateformatter.string(from: future))

        super.willActivate()
    }
    
    override func didAppear() {
       
    }
    
    override func willDisappear() {
        
        // On being sent to the background, it schedules a background refresh
        let future = Date(timeIntervalSinceNow: timeBetweenRefresh)
        scheduleBackgroundRefresh(preferredDate: future)
        let dateformatter = DateFormatter()
        dateformatter.dateStyle = .short
        dateformatter.timeStyle = .short
        print("Scheduling background task from willDisappear: " + dateformatter.string(from: future))

    }
    
    // MARK: Totals
    
    public func totalSteps() -> Double {
        return totalStepCount.doubleValue(for: HKUnit.count())
    }
    
    // Returns the modified step count based on participant number
    public func totalModSteps() -> Double {
        let defaults = UserDefaults.standard
        //convert uid to integer and use as partNum
        let partNum = defaults.integer(forKey: "User ID")
        if (partNum % 3 == 0){
            return self.totalSteps() * 1.4 // Inflated
        } else if (partNum % 3 == 1){
            return self.totalSteps() * 0.6 // Deflated
        } else {
            return self.totalSteps() // Unchanged
        }
        
    }
    
    private func setTotalSteps(steps: Double) {
        totalStepCount = HKQuantity(unit: HKUnit.count(), doubleValue: steps)
    }
    
    // MARK: Convenience
    
    // Convenience method to convert modified step count to actual step count
    public func modToActualSteps(modified: Double) -> Double {
        let defaults = UserDefaults.standard
        //convert uid to integer and use as partNum
        let partNum = defaults.integer(forKey: "User ID")
        if (partNum % 3 == 0){
            return modified / 1.4
        } else if (partNum % 3 == 1){
            return modified / 0.6
        } else {
            return modified
        }
        
    }
    
    func updateLabels() {
        if (self.running == true) {
            modifiedStepCountLabel.setText(format(steps: totalModSteps()))
        } else {
            modifiedStepCountLabel.setText("Learning your steps...")
        }
    }
    
    // Sends data to phone to write to logs, is not relevant, only here because not sure if removal will affect app performance
    func sendDataToPhone(stepCount: Double?, heartRate: Double?, date:Date!) {
        if (stepCount != nil && heartRate == nil) {
         _ = WatchSessionManager.sharedManager.transferUserInfo(userInfo: ["stepCount" : String(format: "%.0f", stepCount!) as AnyObject, "date":String(format:"%f", (date.timeIntervalSince1970)) as AnyObject, "type":stepType])
        } else if (stepCount == nil && heartRate != nil){
        _ = WatchSessionManager.sharedManager.transferUserInfo(userInfo: ["heartRate" : String(format:"%f", heartRate!) as AnyObject, "date":String(format:"%f", (date.timeIntervalSince1970)) as AnyObject, "type":heartType])
        }
    }
    
    // Delivers data to phone to be uploaded to Firebase
    func sendSecondaryDataToPhone(data: Double?, type: Int?, date:Date!){
        _ = WatchSessionManager.sharedManager.transferUserInfo(userInfo: ["data" : String(format:"%f", data!) as AnyObject, "date":String(format:"%f", (date.timeIntervalSince1970)) as AnyObject, "type":type as AnyObject])
    }
    
    func sendDataToServer(stepCount: Double?, heartRate: Double?, date:Date!) {
        let scriptUrl = "https://accusteps-31a48.firebaseio.com/"
        let defaults = UserDefaults.standard
        let uid = defaults.string(forKey: "User ID")
        let timeString = String(format:"%f", (date.timeIntervalSince1970))
        print(timeString)
        var stepCountString = ""
        var heartRateString = ""
        var urlWithParams = scriptUrl + "users/" + uid! + ".json" // The database address to be uploaded
        var bodyString = ""
        
        if (stepCount != nil) {
            
            stepCountString = String(format: "%.0f", stepCount!)
            urlWithParams = scriptUrl + "users/" + uid! + "/stepData" + ".json"
            
            bodyString = "{ \"Time\": \(timeString), \"Count\": \(stepCountString)}" // Structures the data to be uploaded
            
        } else if (heartRate != nil){
            
            heartRateString = String(format: "%.0f", heartRate!)
            urlWithParams = scriptUrl + "users/" + uid! + "/heartData" + ".json"
            
            bodyString = "{ \"Time\": \(timeString), \"Rate\": \(heartRateString) }" // Structures the data to be uploaded
            
        }
        
        let myUrl = URL(string: urlWithParams);
        
        var request = URLRequest(url:myUrl!);
        request.httpBody = bodyString.data(using: .utf8)
    
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            
            if error != nil
            {
                print("error=\(error)")
                return
            }
            let responseString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("responseString = \(responseString)")
        }
        
        task.resume()
    }
    
    // Schedule notification (for another 1000 steps)
    func notifyUser() {
        
        let content = UNMutableNotificationContent()
        
        content.title = "Update:"
        
        if (self.running == true) {
        content.body = String(format: "Current step count: %0.f", self.totalModSteps())
        } else {
        content.body = String(format: "AccuSteps is learning your steps!")
        }
        
        content.sound = UNNotificationSound.default()
        
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 5.0, repeats: false)
        let request = UNNotificationRequest.init(identifier: String(format:"%f", (Date().timeIntervalSince1970)), content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        center.add(request) { (error) in
            if (error != nil) {
                print(error ?? "Error requesting single notification")
            } else {
                print ("Update notification scheduled")
            }
        }
    
        
    }
    
    // Function to update step count.
    func refreshStepCount(){
        let endDate = Date()
        let calendar = NSCalendar.current
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])

        // Sets up time frame for health data to be retrieved
        let stepStartDate = calendar.startOfDay(for: endDate)
        let stepDatePredicate = HKQuery.predicateForSamples(withStart: stepStartDate, end: endDate, options: .strictStartDate)
        let stepPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[stepDatePredicate, devicePredicate])
        
        guard let stepSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount) else {
            NSLog("%@", "Failed to query step count in refreshStepCount");
            return;
            //fatalError("*** This method should never fail ***")
        }
        
        // Organizes data and runs a query to loop through it, accumulating all the steps in the time frame
        let stepQuery = HKStatisticsQuery(quantityType: stepSampleType,
                                          quantitySamplePredicate: stepPredicate,
                                          options: .cumulativeSum) { query, result, error in
                                            
                                            let quantity = result?.sumQuantity()
                                            
                                            var totalSteps = 0.0
                                            
                                            if (quantity != nil && error == nil) {
                                                let unit = HKUnit.count()
                                                totalSteps = (quantity?.doubleValue(for: unit))!
                                            } else if (quantity == nil && error != nil) {
                                                print("An error occured fetching the user's step count data. The error was: \(error?.localizedDescription)");
                                                return
                                            }
                                            
                                            DispatchQueue.main.async { [weak self] in
                                                guard let strongSelf = self else { return }
                                                let prevSteps = strongSelf.totalModSteps()
                                                strongSelf.setTotalSteps(steps: totalSteps)
                                                strongSelf.updateLabels()
                                                
                                                // Saves current step count in Watch
                                                UserDefaults.standard.set(String(format: "%.0f", strongSelf.totalModSteps()), forKey: "stepCount")
                                                
                                                // only if the step count has changed, reload the timeline
                                                if ((Int(strongSelf.totalModSteps()) != Int(prevSteps)) && (strongSelf.running == true)) {
                                              
                                                    let complicationServer = CLKComplicationServer.sharedInstance()
                                                    for complication in complicationServer.activeComplications! {
                                                        complicationServer.reloadTimeline(for: complication) // Update complication
                                                    }
                                                }
                                                
                                                strongSelf.sendDataToServer(stepCount: totalSteps, heartRate: nil, date: endDate)
                                                strongSelf.sendDataToPhone(stepCount: totalSteps, heartRate: nil, date: endDate)
                                            }
                                            
        }
        
        healthStore.execute(stepQuery)

    }
    
    // Similar to refreshStepCount, but for miles cycled. No complications to be sent
    func refreshCycling(){
        
        let endDate = Date()
        let calendar = NSCalendar.current
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        
        let stepStartDate = calendar.startOfDay(for: endDate)
        let stepDatePredicate = HKQuery.predicateForSamples(withStart: stepStartDate, end: endDate, options: .strictStartDate)
        let stepPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[stepDatePredicate, devicePredicate])
        
        guard let stepSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling) else {
            NSLog("%@", "Failed to query step count in refreshWalkRun");
            return;
            //fatalError("*** This method should never fail ***")
        }
        
        let stepQuery = HKStatisticsQuery(quantityType: stepSampleType,
                                          quantitySamplePredicate: stepPredicate,
                                          options: .cumulativeSum) { query, result, error in
                                            
                                            let quantity = result?.sumQuantity()
                                            
                                            var totalSteps = 0.0
                                            
                                            if (quantity != nil && error == nil) {
                                                let unit = HKUnit.mile()
                                                totalSteps = (quantity?.doubleValue(for: unit))!
                                          
                                            } else if (quantity == nil && error != nil) {
                                                print("An error occured fetching the user's walking and running data. The error was: \(error?.localizedDescription)");
                                                return
                                            }
                                            
                                            DispatchQueue.main.async { [weak self] in
                                                guard let strongSelf = self else { return }
                                                strongSelf.sendSecondaryData(data: totalSteps, date: endDate, type: "cycle")
                                                strongSelf.sendSecondaryDataToPhone(data: totalSteps, type: 3, date: endDate)
                                            }
        }
        
        healthStore.execute(stepQuery)
        
    }

    // Similar to refreshStepCount, but for miles walked and ran. No complications to be sent
    func refreshWalkRun(){
        let endDate = Date()
        let calendar = NSCalendar.current
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        
        let stepStartDate = calendar.startOfDay(for: endDate)
        let stepDatePredicate = HKQuery.predicateForSamples(withStart: stepStartDate, end: endDate, options: .strictStartDate)
        let stepPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[stepDatePredicate, devicePredicate])
        
        guard let stepSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning) else {
            NSLog("%@", "Failed to query step count in refreshWalkRun");
            return;
            //fatalError("*** This method should never fail ***")
        }
        
        let stepQuery = HKStatisticsQuery(quantityType: stepSampleType,
                                          quantitySamplePredicate: stepPredicate,
                                          options: .cumulativeSum) { query, result, error in
                                            
                                            let quantity = result?.sumQuantity()
                                            
                                            var totalSteps = 0.0
                                            
                                            if (quantity != nil && error == nil) {
                                                let unit = HKUnit.mile()
                                                totalSteps = (quantity?.doubleValue(for: unit))!
                                              
                                            } else if (quantity == nil && error != nil) {
                                                print("An error occured fetching the user's walking and running data. The error was: \(error?.localizedDescription)");
                                                return
                                            }
                                            
                                            DispatchQueue.main.async { [weak self] in
                                                guard let strongSelf = self else { return }
                                                strongSelf.sendSecondaryData(data: totalSteps, date: endDate, type: "walkRun")
                                                strongSelf.sendSecondaryDataToPhone(data: totalSteps, type: 2, date: endDate)
                                            }
                                            
        }
        
        healthStore.execute(stepQuery)
        
    }

    // Similar to refreshStepCount, but for active calories burnt. No complications to be sent
    func refreshActiveCalories(){
        let endDate = Date()
        let calendar = NSCalendar.current
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        
        let stepStartDate = calendar.startOfDay(for: endDate)
        let stepDatePredicate = HKQuery.predicateForSamples(withStart: stepStartDate, end: endDate, options: .strictStartDate)
        let stepPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[stepDatePredicate, devicePredicate])
        
        guard let stepSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned) else {
            NSLog("%@", "Failed to query step count in refreshWalkRun");
            return;
            //fatalError("*** This method should never fail ***")
        }
        
        let stepQuery = HKStatisticsQuery(quantityType: stepSampleType,
                                          quantitySamplePredicate: stepPredicate,
                                          options: .cumulativeSum) { query, result, error in
                                           
                                            let quantity = result?.sumQuantity()
                                            
                                            var totalSteps = 0.0
                                            
                                            if (quantity != nil && error == nil) {
                                                let unit = HKUnit.kilocalorie()
                                                totalSteps = (quantity?.doubleValue(for: unit))!
                                            
                                            } else if (quantity == nil && error != nil) {
                                                print("An error occured fetching the user's walking and running data. The error was: \(error?.localizedDescription)");
                                                return
                                            }
                                            
                                            DispatchQueue.main.async { [weak self] in
                                                guard let strongSelf = self else { return }
                                                strongSelf.sendSecondaryData(data: totalSteps, date: endDate, type: "active")
                                                strongSelf.sendSecondaryDataToPhone(data: totalSteps, type: 4, date: endDate)
                                            }
                        }
        
        healthStore.execute(stepQuery)
        
    }

    // Similar to refreshStepCount, but for dormant calories burnt. No complications to be sent
    func refreshBasalCalories() {
        let endDate = Date()
        let calendar = NSCalendar.current
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        
        let stepStartDate = calendar.startOfDay(for: endDate)
        let stepDatePredicate = HKQuery.predicateForSamples(withStart: stepStartDate, end: endDate, options: .strictStartDate)
        let stepPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[stepDatePredicate, devicePredicate])
        
        guard let stepSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.basalEnergyBurned) else {
            NSLog("%@", "Failed to query step count in refreshWalkRun");
            return;
            //fatalError("*** This method should never fail ***")
        }
        
        let stepQuery = HKStatisticsQuery(quantityType: stepSampleType,
                                          quantitySamplePredicate: stepPredicate,
                                          options: .cumulativeSum) { query, result, error in
                                           
                                            let quantity = result?.sumQuantity()
                                            
                                            var totalSteps = 0.0
                                            
                                            if (quantity != nil && error == nil) {
                                                let unit = HKUnit.kilocalorie()
                                                totalSteps = (quantity?.doubleValue(for: unit))!
                                              
                                            } else if (quantity == nil && error != nil) {
                                                print("An error occured fetching the user's walking and running data. The error was: \(error?.localizedDescription)");
                                                return
                                            }
                                            
                                            DispatchQueue.main.async { [weak self] in
                                                guard let strongSelf = self else { return }
                                                strongSelf.sendSecondaryData(data: totalSteps, date: endDate, type: "basal")
                                                strongSelf.sendSecondaryDataToPhone(data: totalSteps, type: 5, date: endDate)
                                            }
                        }
        
        healthStore.execute(stepQuery)
        
    }
    
    // Similar to refreshStepCount, but for minutes spent exercising. No complications to be sent
    func refreshExerciseMinutes(){
        let endDate = Date()
        let calendar = NSCalendar.current
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        
        let stepStartDate = calendar.startOfDay(for: endDate)
        let stepDatePredicate = HKQuery.predicateForSamples(withStart: stepStartDate, end: endDate, options: .strictStartDate)
        let stepPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[stepDatePredicate, devicePredicate])
        
        guard let stepSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.appleExerciseTime) else {
            NSLog("%@", "Failed to query step count in refreshWalkRun");
            return;
            //fatalError("*** This method should never fail ***")
        }
        
        let stepQuery = HKStatisticsQuery(quantityType: stepSampleType,
                                          quantitySamplePredicate: stepPredicate,
                                          options: .cumulativeSum) { query, result, error in
                                           
                                            let quantity = result?.sumQuantity()
                                            
                                            var totalSteps = 0.0
                                            
                                            if (quantity != nil && error == nil) {
                                                let unit = HKUnit.minute()
                                                totalSteps = (quantity?.doubleValue(for: unit))!
                                           
                                            } else if (quantity == nil && error != nil) {
                                                print("An error occured fetching the user's walking and running data. The error was: \(error?.localizedDescription)");
                                                return
                                            }
                                            
                                            DispatchQueue.main.async { [weak self] in
                                                guard let strongSelf = self else { return }
                                                strongSelf.sendSecondaryData(data: totalSteps, date: endDate, type: "exercise")
                                                strongSelf.sendSecondaryDataToPhone(data: totalSteps, type: 7, date: endDate)
                                            }
                        }
        
        healthStore.execute(stepQuery)
        
    }

    // Function to keep checking notifyCounter. If it reaches 7, it will send an update notification and then reset notifyCounter to 0. This keeps repeating. In baseline week, it will only send around 1 notification per day
    func testNotifyRefresh(){
        
        if (self.running == true) {
        if (UserDefaults.standard.string(forKey: "notifyCounter") != nil) {
        let count = UserDefaults.standard.integer(forKey: "notifyCounter")
        if (count == 7) {
            
            self.notifyUser()
            UserDefaults.standard.set("0", forKey: "notifyCounter")
 
        } else {
            
            let replace = count+1
            UserDefaults.standard.set("\(replace)", forKey: "notifyCounter")

            }
        } else {
            UserDefaults.standard.set("0", forKey: "notifyCounter")
        }
        
        } else {
            if (UserDefaults.standard.string(forKey: "notifyCounter") != nil) {
                let count = UserDefaults.standard.integer(forKey: "notifyCounter")
                if (count == 31) {
                    
                    self.notifyUser()
                    UserDefaults.standard.set("0", forKey: "notifyCounter")
                    
                } else {
                    
                    let replace = count+1
                    UserDefaults.standard.set("\(replace)", forKey: "notifyCounter")
                    
                }
            } else {
                UserDefaults.standard.set("0", forKey: "notifyCounter")
            }
        }
    }
    
    
    // Function to update step count and send steps and heart rate to server/phone all in the background
    // This function is called by the system when our app is in the background (we ask for this function
    // to be called when we call 'scheduleBackgroundRefresh')
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        
        let startDate = UserDefaults.standard.object(forKey: "startDate") as! Date
        
        // If the Watch has not reached the date entered on the iPhone yet, it will not update steps
        if (running == false) {
            if (UserDefaults.standard.object(forKey: "startDate") == nil) {
                let toCheck = ["fromWatch" : "checkID"]
                WatchSessionManager.sharedManager.sendMessage(message: toCheck) { (success) -> Void in
                    if success {
                       // Do nothing
                    }
                    else {
                       UserDefaults.standard.set(Date(), forKey: "startDate")
                    }
                }
            } else if (startDate < Date()) {
                
                self.running = true
                            }
        }
        
        // Schedules another same background task
        let future = Date(timeIntervalSinceNow: self.timeBetweenRefresh)
        self.scheduleBackgroundRefresh(preferredDate: future)
        print("Scheduling background task from background task handle")
        
        let refreshFlights = ["refresh":"flights"]
        
        WatchSessionManager.sharedManager.message(message: refreshFlights) { (success) -> Void in
            if success {
                // Flights climbed data has been sent to iPhone
            }
        }
        
        // All the data uplooad functions
        self.refreshBasalCalories()
        self.refreshActiveCalories()
        self.refreshWalkRun()
        self.refreshCycling()
        self.refreshExerciseMinutes()
        
        var stepsFinished = false
        var heartFinished = false
        let endDate = Date()
        let calendar = NSCalendar.current
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        guard let heartSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            NSLog("%@", "Failed to query heart rate in handle background task");
            return;
            //fatalError("*** This method should never fail ***")
        }
        
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()]) // Only get samples from the watch (not the phone)
        
        // Extract the heart rate data
        let heartStartDate = UserDefaults.standard.object(forKey: "heartLastDate") as! Date
        let heartDatePredicate = HKQuery.predicateForSamples(withStart: heartStartDate, end: endDate, options: .strictStartDate)
        let heartPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[heartDatePredicate, devicePredicate])
        
        let heartQuery = HKSampleQuery(sampleType: heartSampleType, predicate: heartPredicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: [sortDescriptor]) {
            query, results, error in
            
            guard let samples = results as? [HKQuantitySample] else {
                NSLog("%@", "An error occurred fetching the user's heart rate data in handle background task");
                //fatalError("An error occured fetching the user's heart rate data. The error was: \(error?.localizedDescription)");
                // if this fails and schedule a push notification
                return;
            }
            
            DispatchQueue.main.async { [weak self] in
                
                guard let strongSelf = self else { return }
                var latest: Date?
                latest = nil
                 // This finds the latest heart rate sample among the data
                for sample in samples {
                    
                    print(sample)
                    print ("start:")
                    print (sample.startDate)
                    print ("end:")
                    print (sample.endDate)
                    if (latest == nil || latest?.compare(sample.endDate) == ComparisonResult.orderedAscending) {
                        
                        latest = sample.endDate
                    }
                
                    let newHeart = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
    
                    strongSelf.sendDataToServer(stepCount: nil, heartRate: newHeart, date:sample.startDate)
                    strongSelf.sendDataToPhone(stepCount: nil, heartRate: newHeart, date: sample.startDate)
                }
                
                if (latest != nil){
                    UserDefaults.standard.set(latest, forKey: "heartLastDate") // It sets the latest heart rate date as the start of the next time frame to get data from
                    print("NEXT HEART START DATE")
                    print(latest!)
                }
                
                if (stepsFinished) { // If the steps query already finished, mark the background tasks as complete
                    
                    for task : WKRefreshBackgroundTask in backgroundTasks {
                        task.setTaskCompleted()
                    }
                } else {
                    
                    heartFinished = true
                }
            }
        }
        
        guard let stepSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount) else {
            NSLog("%@", "Failed to query step count in handle background task");
            return;
        }
        
        // Extract the step count data
        let stepStartDate = calendar.startOfDay(for: endDate)
        let stepDatePredicate = HKQuery.predicateForSamples(withStart: stepStartDate, end: endDate, options: .strictStartDate)
        let stepPredicate = NSCompoundPredicate(andPredicateWithSubpredicates:[stepDatePredicate, devicePredicate])
        
        let stepQuery = HKStatisticsQuery(quantityType: stepSampleType,
                                          quantitySamplePredicate: stepPredicate,
                                          options: .cumulativeSum) { query, result, error in
                                            
                                            let quantity = result?.sumQuantity()
                                            
                                            var totalSteps = 0.0
                                            
                                            if (quantity != nil && error == nil) {
                                                let unit = HKUnit.count()
                                                totalSteps = (quantity?.doubleValue(for: unit))!
                                                
                                            } else if (quantity == nil && error != nil) {
                                                print("An error occured fetching the user's step count data. The error was: \(error?.localizedDescription)");
                                                return
                                            }
                                            
                                            print("TOTAL STEPS FOR DAY:")
                                            print(totalSteps)
                                            
                                            DispatchQueue.main.async { [weak self] in
                                                guard let strongSelf = self else { return }
                                                let prevSteps = strongSelf.totalModSteps()
                                                strongSelf.setTotalSteps(steps: totalSteps)
                                                strongSelf.updateLabels()
                                                strongSelf.testNotifyRefresh()
                                                
                                                UserDefaults.standard.set(String(format: "%.0f", strongSelf.totalModSteps()), forKey: "stepCount")
                                                
                                                // only if the step count has changed, reload the timeline
                                                if ((Int(strongSelf.totalModSteps()) != Int(prevSteps)) && (strongSelf.running == true)) {
                                                    let complicationServer = CLKComplicationServer.sharedInstance()
                                                    for complication in complicationServer.activeComplications! {
                                                        complicationServer.reloadTimeline(for: complication) // Update complication
                                                    }
                                                    
                                                }
                                               
                                                strongSelf.sendDataToPhone(stepCount: totalSteps, heartRate: nil, date: endDate)
                                                strongSelf.sendDataToServer(stepCount: totalSteps, heartRate: nil, date: endDate)
                                                let toPhone = ["setting": "\(Int(strongSelf.totalModSteps()))"]
                                                WatchSessionManager.sharedManager.message(message: toPhone) { (success) -> Void in
                                                    if success {
                                                        // Sent to iPhone
                                                    }
                                                }
                                                
                                                if (heartFinished) { // If the heart query already finished, mark the background tasks as complete
                                                    for task : WKRefreshBackgroundTask in backgroundTasks {
                                                        task.setTaskCompleted()
                                                    }
                                                } else {
                                                    
                                                    stepsFinished = true
                                                }
                                            }
                            }
        
        healthStore.execute(stepQuery)
        healthStore.execute(heartQuery)
    }
    
    func scheduleBackgroundRefresh(preferredDate: Date?) {
        if let preferredDate = preferredDate {
            let completion: (Error?) -> Void = { (error) in
                // Handle error if needed
                if (error == nil) {
                    
                    print("Successfully scheduled background task")
                } else {
                    
                    print(error ?? "Error scheduling next background refresh")
                }
            }
            
            WKExtension.shared().scheduleBackgroundRefresh(
                withPreferredDate: preferredDate,
                userInfo: nil,
                scheduledCompletion: completion
            )
        }
    }
    
    // This uploads all the health data needed to the Firebase database
    func sendSecondaryData(data: Double?, date: Date!, type: String!) {
        let scriptUrl = "https://accusteps-31a48.firebaseio.com/"
        let defaults = UserDefaults.standard
        let uid = defaults.string(forKey: "User ID")
        let timeString = String(format:"%f", (date.timeIntervalSince1970))
        print(timeString)
        var flightCountString = ""
        var urlWithParams = scriptUrl + "users/" + uid! + ".json"
        var bodyString = ""
        
        if (type == "walkRun") {
            flightCountString = String(format: "%.0f", data!)
            urlWithParams = scriptUrl + "users/" + uid! + "/walkRunDistanceData" + ".json"
            
            bodyString = "{ \"Time\": \(timeString), \"Rate\": \(flightCountString) }"
            
            print(urlWithParams)
            print(bodyString)
        }
        if (type == "cycle") {
            flightCountString = String(format: "%.0f", data!)
            urlWithParams = scriptUrl + "users/" + uid! + "/cyclingDistanceData" + ".json"
            
            bodyString = "{ \"Time\": \(timeString), \"Rate\": \(flightCountString) }"
            
            print(urlWithParams)
            print(bodyString)
        }
        if (type == "active") {
            flightCountString = String(format: "%.0f", data!)
            urlWithParams = scriptUrl + "users/" + uid! + "/activeCaloriesData" + ".json"
            
            bodyString = "{ \"Time\": \(timeString), \"Rate\": \(flightCountString) }"
            
            print(urlWithParams)
            print(bodyString)
        }
        if (type == "basal") {
            flightCountString = String(format: "%.0f", data!)
            urlWithParams = scriptUrl + "users/" + uid! + "/basalCaloriesData" + ".json"
            
            bodyString = "{ \"Time\": \(timeString), \"Rate\": \(flightCountString) }"
            
            print(urlWithParams)
            print(bodyString)
        }
        if (type == "exercise") {
            flightCountString = String(format: "%.0f", data!)
            urlWithParams = scriptUrl + "users/" + uid! + "/exerciseMinutesData" + ".json"
            
            bodyString = "{ \"Time\": \(timeString), \"Rate\": \(flightCountString) }"
            
            print(urlWithParams)
            print(bodyString)
        }
        
        let myUrl = URL(string: urlWithParams);
        
        var request = URLRequest(url:myUrl!);
        request.httpBody = bodyString.data(using: .utf8)
        
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            
            if error != nil
            {
                print("error=\(error)")
                return
            }
            let responseString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
        }
        
        task.resume()
    }
    
}

