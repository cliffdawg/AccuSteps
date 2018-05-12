//
//  HKQuantityTypeExtension.swift
//  AccuSteps
//
//  Created by Clifford Yin on 6/27/17.
//  Copyright © 2017 Stanford University HCI. All rights reserved.
//

import Foundation
import HealthKit

extension HKQuantityType {
    static func distanceWalkingRunning() -> HKQuantityType {
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)!
    }
    
    static func distanceCycling() -> HKQuantityType {
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling)!
    }
    
    static func activeEnergyBurned() -> HKQuantityType {
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!
    }
    
    static func heartRate() -> HKQuantityType {
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
    }
}
