/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class manages the HealthKit interactions and provides a delegate
 to indicate changes in data.
 */

import Foundation
import HealthKit

/**
 `WorkoutManagerDelegate` exists to inform delegates of swing data changes.
 These updates can be used to populate the user interface.
 */
protocol WorkoutManagerDelegate: class {
    func didUpdateMotion(_ manager: WorkoutManager, magnX:Double?, magnY:Double?, magnZ:Double?, gravX:Double?, gravY:Double?, gravZ:Double?, rotatX:Double?, rotatY:Double?, rotatZ:Double?, useraccX:Double?, useraccY:Double?, useraccZ:Double?, attdW:Double?, attdX:Double?, attdY:Double?, attdZ:Double?, timestamp: Int64)
}

class WorkoutManager: MotionManagerDelegate {
    // MARK: Properties
    let motionManager = MotionManager()
    let healthStore = HKHealthStore()
    
    weak var delegate: WorkoutManagerDelegate?
    var session: HKWorkoutSession?
    
    // MARK: Initialization
    
    init() {
        motionManager.delegate = self
    }
    
    // MARK: WorkoutManager
    
    func startWorkout() {
        // If we have already started the workout, then do nothing.
        if (session != nil) {
            return
        }
        
        // Configure the workout session.
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .mixedCardio
        workoutConfiguration.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(configuration: workoutConfiguration)
        } catch {
            fatalError("Unable to create the workout session!")
        }
        
        // Start the workout session and device motion updates.
        healthStore.start(session!)
        motionManager.startUpdates()
    }
    
    func stopWorkout() {
        // If we have already stopped the workout, then do nothing.
        if (session == nil) {
            return
        }
        
        // Stop the device motion updates and workout session.
        motionManager.stopUpdates()
        healthStore.end(session!)
        
        // Clear the workout session.
        session = nil
    }
    
    // MARK: MotionManagerDelegate
    
    func didUpdateMotion(_ manager: MotionManager, magnX:Double?, magnY:Double?, magnZ:Double?, gravX:Double?, gravY:Double?, gravZ:Double?, rotatX:Double?, rotatY:Double?, rotatZ:Double?, useraccX:Double?, useraccY:Double?, useraccZ:Double?, attdW:Double?, attdX:Double?, attdY:Double?, attdZ:Double?, timestamp: Int64) {
        delegate?.didUpdateMotion(self, magnX: magnX, magnY: magnY, magnZ: magnZ, gravX: gravX, gravY: gravY, gravZ: gravZ, rotatX: rotatX, rotatY: rotatY, rotatZ: rotatZ, useraccX: useraccX, useraccY: useraccY, useraccZ: useraccZ,  attdW: attdW, attdX: attdX, attdY: attdY, attdZ: attdZ, timestamp: timestamp)
    }
}
