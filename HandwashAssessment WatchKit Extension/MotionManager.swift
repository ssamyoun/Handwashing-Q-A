/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This class manages the CoreMotion interactions and
 provides a delegate to indicate changes in data.
 */

import Foundation
import CoreMotion
import WatchKit
import os.log
/**
 `MotionManagerDelegate` exists to inform delegates of motion changes.
 These contexts can be used to enable application specific behavior.
 */
protocol MotionManagerDelegate: class {
    func didUpdateMotion(_ manager: MotionManager, magnX:Double?, magnY:Double?, magnZ:Double?, gravX:Double?, gravY:Double?, gravZ:Double?, rotatX:Double?, rotatY:Double?, rotatZ:Double?, useraccX:Double?, useraccY:Double?, useraccZ:Double?, attdW:Double?, attdX:Double?, attdY:Double?, attdZ:Double?, timestamp: Int64)
}

extension Date {
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded()) // * 1000.0
    }
}

class MotionManager {
    // MARK: Properties
    
    let motionManager = CMMotionManager()
    let queue = OperationQueue()
    //let queue2 = OperationQueue()
    let wristLocationIsLeft = WKInterfaceDevice.current().wristLocation == .left
    
    // MARK: Application Specific Constants
    
    // The app is using 50hz data and the buffer is going to hold 1s worth of data.
    let sampleInterval = 1.0 / 50
    let rateAlongGravityBuffer = RunningBuffer(size: 50)
    
    weak var delegate: MotionManagerDelegate?

    var timeStamp: Int64 = 0
    
    var recentDetection = false
    
    // MARK: Initialization
    
    init() {
        // Serial queue for sample handling and calculations.
        queue.maxConcurrentOperationCount = 1
        queue.name = "MotionManagerQueue"
        
//        queue2.maxConcurrentOperationCount = 1
//        queue2.name = "AcceleroQueue"
    }
    
    func startUpdates() {
        if !motionManager.isDeviceMotionAvailable {
            print("Device Motion is not available.")
            return
        }
        
        os_log("Start Updates");

        motionManager.deviceMotionUpdateInterval = sampleInterval
        motionManager.startDeviceMotionUpdates(to: queue) { (deviceMotion: CMDeviceMotion?, error: Error?) in
            if error != nil {
                print("Encountered error: \(error!)")
            }
            
            if deviceMotion != nil {
                self.processDeviceMotion(deviceMotion!)
            }
        }
//        motionManager.startAccelerometerUpdates(to: queue2, withHandler: {(accelerData:CMAccelerometerData?, error: Error?) in
//            if (error != nil ) {
//                print("Encountered error: \(error!)")
//            }
//            if accelerData != nil {
//                self.processAcceleroData(accelerData!)
//            }
//        })
        
    }
    
    func stopUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.stopDeviceMotionUpdates()
        }
//        if motionManager.isAccelerometerAvailable {
//            motionManager.stopAccelerometerUpdates()
//        }
    }

    func processDeviceMotion(_ deviceMotion: CMDeviceMotion) {
        timeStamp = Date().millisecondsSince1970
        delegate?.didUpdateMotion(self, magnX: deviceMotion.magneticField.field.x, magnY: deviceMotion.magneticField.field.y, magnZ: deviceMotion.magneticField.field.z, gravX: deviceMotion.gravity.x, gravY: deviceMotion.gravity.y, gravZ: deviceMotion.gravity.z, rotatX: deviceMotion.rotationRate.x, rotatY: deviceMotion.rotationRate.y, rotatZ: deviceMotion.rotationRate.z, useraccX: deviceMotion.userAcceleration.x, useraccY: deviceMotion.userAcceleration.y, useraccZ: deviceMotion.userAcceleration.z, attdW: deviceMotion.attitude.quaternion.w, attdX: deviceMotion.attitude.quaternion.x, attdY: deviceMotion.attitude.quaternion.y, attdZ: deviceMotion.attitude.quaternion.z, timestamp: timeStamp)
    }
    
//    func processAcceleroData(_ acceleroData: CMAccelerometerData) {
//        timeStamp = Date().millisecondsSince1970
//        delegate?.didUpdateMotion(self, magnX: acceleroData.acceleration.x, magnY: acceleroData.acceleration.y, magnZ: acceleroData.acceleration.z, gravX: nil, gravY: nil, gravZ: nil, rotatX: nil, rotatY: nil, rotatZ: nil, useraccX: nil, useraccY: nil, useraccZ: nil, attdW: nil, attdX: nil, attdY: nil, attdZ: nil, timestamp: timeStamp)
//
//    }
}
