//
//  Complication.swift
//  AccuSteps
//
//  Created by Clifford Yin on 6/26/17.
//  Copyright © 2017 Stanford University HCI. All rights reserved.
//



import ClockKit
import HealthKit

/* Code for the Watch app complication controller */
class Complication: NSObject, CLKComplicationDataSource {
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Swift.Void) {
        handler([])
    }
    
    // Updates the complication with received data
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Swift.Void) {
        if complication.family == .modularLarge {
            
            let template = CLKComplicationTemplateModularLargeTallBody()
            var stepCountString = UserDefaults.standard.string(forKey: "stepCount")
            
            if (stepCountString == nil) {
                stepCountString = "Restart" // If no step count, means app crashed and needs restart
            }
            
            // If this is the first complication sent out, black it out until the date entered in the iphone has been reached
            if (UserDefaults.standard.object(forKey: "complicate") == nil) {
                stepCountString = "................................"
                UserDefaults.standard.set(Date(), forKey: "complicate")
            }
            
            template.bodyTextProvider = CLKSimpleTextProvider(text: stepCountString!)
            template.headerTextProvider = CLKSimpleTextProvider(text: "Step Count")
            
            let timelineEntry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(timelineEntry)
        } else {
            handler(nil)
        }
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Swift.Void) {
        handler(CLKComplicationPrivacyBehavior.showOnLockScreen)
    }
    
    func getNextRequestedUpdateDate(handler: @escaping (Date?) -> Swift.Void) {
        handler(Date(timeIntervalSinceNow: 600))
    }
    
    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Swift.Void) {
        if complication.family == .modularLarge {
            let template = CLKComplicationTemplateModularLargeTallBody()
            template.bodyTextProvider = CLKSimpleTextProvider(text: "AccuSteps")
            template.headerTextProvider = CLKSimpleTextProvider(text: "Step Count")
            handler(template)
        } else {
            handler(nil)
        }
    }
}

