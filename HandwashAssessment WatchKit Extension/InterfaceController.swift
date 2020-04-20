//
//  InterfaceController.swift
//  HandwashAssessment WatchKit Extension
//
//  Created by Sirat Samyoun on 4/12/20.
//  Copyright © 2020 Sirat Samyoun. All rights reserved.
//

import WatchKit
import Foundation
import UIKit
import UserNotifications
import AVFoundation
import WatchConnectivity
import CoreLocation
import CoreBluetooth
import CoreML


//audio enabling info.plist
//test beacon, reminder, realtime pred

class InterfaceController: WKInterfaceController,WorkoutManagerDelegate,CBCentralManagerDelegate,UNUserNotificationCenterDelegate,AVSpeechSynthesizerDelegate {
    
    let serviceIds = [CBUUID(string: "FE9A")]
    let primaryBeaconId: String = "114ebf586b0579cba35"//"114ebf586b0579cba35f32869f538c9b1ec101-coco1-2de17af2" //-45(closest) -65(closer) -75(close)
    let hwModel = main_file()
    let samplingrate:Int = 50 //let bunch_size = 30  # 30*9 = 270 for one pred   let window_len = 2 //100 samples a window let sliding_len =  1 //50 samples
    let totalColsSens:Int = 16
    let totalRowsSens:Int = 3000//3000 =60 seconds *50 samples
    var sensorReadings:[[Double?]] = Array(repeating: Array(repeating: 0.0, count: 16), count: 3000)  //print(tempA[2999][12]) //83.423
    var sensorReadingIndex:Int = 0
    
    var workoutManager = WorkoutManager()
    var centralManager : CBCentralManager!
    var peripheral: CBPeripheral!
    var keepAlivetimer : Timer? //also for scan
    let keepAliverInterval: Double = 1.0 //5sec
    var currentResponseText:String = ""
    var conversationFinished = false
    var currentResponseResult = 0
    var synth: AVSpeechSynthesizer?
    var myUtterance = AVSpeechUtterance(string: "")
    
    var resultsArray = [Int]()//[[Double]]()
    var feedBackArray = [String]()
    var startTime = 0.0
    var endTime = 0.0
    
    func startBeaconSensingAndRemind(){
        WKInterfaceDevice.current().play(.success)
        WKInterfaceDevice.current().play(.click)
        reminded = false
        keepAlivetimer = Timer.scheduledTimer(timeInterval: keepAliverInterval, target: self, selector: #selector(onKeepAliveTimerTick), userInfo: nil, repeats: true)
        RunLoop.current.add(keepAlivetimer!, forMode: RunLoop.Mode.common)
    }
    
    func startCollectIMU(){
        //resetCurrentValuesAtStart()//currentAppState = 1
        WKInterfaceDevice.current().play(.success)
        WKInterfaceDevice.current().play(.click)
        
        sensorReadings = Array(repeating: Array(repeating: 0.0, count: totalColsSens), count: totalRowsSens)  //print(tempA[2999][12]) //83.423
        sensorReadingIndex = 0
        workoutManager.startWorkout()
    }
    
    @objc func onKeepAliveTimerTick() -> Void {
        if centralManager.state == .poweredOn && !centralManager.isScanning{
            centralManager.scanForPeripherals(withServices: serviceIds, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    func getDataAndProcessInModel(){ //3000*16 to *9
        resultsArray = [Int]()
        var dataToCheckHW = sensorReadings //func here
        var maxIdx = sensorReadingIndex //dataToCheckHW.count
        var startIdx = 0, endIdx = 49
        while true{
            if (endIdx >= maxIdx){
                break
            }
            //one prediction from 50*16
            var mlArray = try? MLMultiArray(shape:[800],dataType:MLMultiArrayDataType.double)
            var mlIdx = 0
            for k in startIdx...endIdx {
                let tmp = dataToCheckHW[k]
                for elem in tmp
                {
                    mlArray![mlIdx] = NSNumber(floatLiteral: elem!)
                    mlIdx += 1
                }
            }
            let outputLabel = PredictLabel(mlMultiArrayInput: mlArray!)
            resultsArray.append(outputLabel)
            //
            endIdx = min(maxIdx,endIdx+25)
            startIdx = endIdx-49
        }
    }
    
    func PredictLabel(mlMultiArrayInput:MLMultiArray)->Int{
        let prediction = try? hwModel.prediction(imu: mlMultiArrayInput, bidirectional_2_h_in: nil, bidirectional_2_c_in: nil, bidirectional_2_h_in_rev: nil, bidirectional_2_c_in_rev: nil)
        print("prediction:",prediction?.output)
        var maxIdx = 0
        var maxVal = -1.0
        for n in 0...9 {
            let v = Double(((prediction?.output[n])!))
            if(v>maxVal){
                maxVal = v
                maxIdx = n
            }
        }
        return (maxIdx + 1)
    }
    
    
    
    func callformalAndFeedback(){
        print("resultsArray-->", resultsArray)
        feedBackArray = [String]()
        let duration = endTime - startTime
        if (duration < 20){
            feedBackArray.append("Didn't wash for 20 seconds")
        }
        if (!(resultsArray.first == 1)){
            feedBackArray.append("Didn't rub hands properly")
        }
        if (!(resultsArray.contains(2)) && !(resultsArray.contains(3))){
            feedBackArray.append("Didn't put palm over hands properly")
        }
        if (!(resultsArray.contains(4))){
            feedBackArray.append("Didn't interlace fingers properly")
        }
        if (!(resultsArray.contains(5)) && !(resultsArray.contains(6))){ 
            feedBackArray.append("Didn't clean fingertips properly")
        }
        if (!(resultsArray.contains(7)) && !(resultsArray.contains(8))){
            feedBackArray.append("Didn't rub thumbs properly")
        }
        if (!(resultsArray.contains(9)) && !(resultsArray.contains(10))){
            feedBackArray.append("Didn't put fingers on palms properly")
        }
        if(feedBackArray.isEmpty){
            feedBackArray.append("Great Job! You washed hands perfectly")
        }
        let utter = feedBackArray.joined(separator: ", ")
        utterSentence(line: utter)
    }
    
    func didUpdateMotion(_ manager: WorkoutManager, magnX:Double?, magnY:Double?, magnZ:Double?, gravX:Double?, gravY:Double?, gravZ:Double?, rotatX:Double?, rotatY:Double?, rotatZ:Double?, useraccX:Double?, useraccY:Double?, useraccZ:Double?, attdW:Double?, attdX:Double?, attdY:Double?, attdZ:Double?, timestamp: Int64) {
        DispatchQueue.main.async {
            self.sensorReadings[self.sensorReadingIndex][0] = useraccX
            self.sensorReadings[self.sensorReadingIndex][1] = useraccY
            self.sensorReadings[self.sensorReadingIndex][2] = useraccZ
            self.sensorReadings[self.sensorReadingIndex][3] = gravX
            self.sensorReadings[self.sensorReadingIndex][4] = gravY
            self.sensorReadings[self.sensorReadingIndex][5] = gravZ
            self.sensorReadings[self.sensorReadingIndex][6] = rotatX
            self.sensorReadings[self.sensorReadingIndex][7] = rotatY
            self.sensorReadings[self.sensorReadingIndex][8] = rotatZ
            self.sensorReadings[self.sensorReadingIndex][9] = attdW
            self.sensorReadings[self.sensorReadingIndex][10] = attdX
            self.sensorReadings[self.sensorReadingIndex][11] = attdY
            self.sensorReadings[self.sensorReadingIndex][12] = attdZ
            self.sensorReadings[self.sensorReadingIndex][13] = magnX
            self.sensorReadings[self.sensorReadingIndex][14] = magnY
            self.sensorReadings[self.sensorReadingIndex][15] = magnZ
            
            self.sensorReadingIndex = self.sensorReadingIndex + 1
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var advertisementDataString = ""
        var adId = ""
        let adDictionary = advertisementData as NSDictionary
        if let val = adDictionary["kCBAdvDataServiceData"] {
            advertisementDataString = ((val as AnyObject).description).replacingOccurrences(of: "\n", with: "")
            adId = getAdvertisementIds(adStr: (val as AnyObject).description)
        }
        //print("Beacon: ", adId)
        if (reminded == false && adId.contains(primaryBeaconId)){ //and DBB //starts with
            print("desired beacon found", primaryBeaconId, RSSI.stringValue)
            if(Int(RSSI.stringValue)! > -65){
                //start interact
                setNotificationAfterSeconds(secs: 2)
                reminded = true
                centralManager.stopScan()
            }
        }
    }
    
    var reminded:Bool = false
    
    func getAdvertisementIds(adStr: String) -> String{ //(String, String)
        var serviceId = ""
        var advertisementId = ""
        do {
            let advString = adStr.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "{", with: "")
            let strs = advString.components(separatedBy: "=")
            if(strs.count == 2){
                serviceId = strs[0]
                let str2 = strs[1]
                let regex = try NSRegularExpression(pattern:"<(.*)>")
                if let match = regex.firstMatch(
                    in: str2, range:NSMakeRange(0,str2.utf16.count)) {
                    advertisementId = (str2 as NSString).substring(with: match.range(at:1))
                }
            }
        } catch {
            print("error")
        }
        return (advertisementId) //serviceId,
    }
    
    func handleFirstResponse(){
        if (currentResponseText.isEmpty == false) {
            var responseStr = currentResponseText
            currentResponseText = ""
            currentResponseResult = ResponseType.respondedNotUnderstood.rawValue //not yet
            responseStr = responseStr.lowercased()
            if (responseStr.contains("yes") || responseStr.contains("done") || responseStr.contains("did")
                || responseStr.contains("yeah") || responseStr.contains("sure") || responseStr.contains("taken") || responseStr.contains("took")
                ){
                currentResponseResult = ResponseType.respondedWithConfirmedTaking.rawValue
                conversationFinished = true
                utterSentence(line: "Ok. Press start button before beginning to wash.")
            }
            else if (responseStr.contains("done") || responseStr.contains("did")){
                if (responseStr.contains("thank")){
                    utterSentence(line: "You are welcome.");
                } else{
                    utterSentence(line: "Ok. Thank you.");
                }
            }
            else if (responseStr.contains("how") || responseStr.contains("details") || responseStr.contains("describe") || responseStr.contains("more") || responseStr.contains("what") || responseStr.contains("which")){
                let details:String = "Take the soap, rub your hands, and clean with water for 20 seconds"
                utterSentence(line: details)
            }
            else if (responseStr.contains("repeat") || responseStr.contains("what") || responseStr.contains("again") ) {
                let details:String = "Take the soap, rub your hands, and clean with water for 20 seconds"
                utterSentence(line: details)
            }
            else if (responseStr.contains("remind")) {
                if (responseStr.contains("don't") || responseStr.contains("do not")){
                    currentResponseResult = ResponseType.respondedWithStop.rawValue
                    conversationFinished = true
                }
                else if (responseStr.contains("later")){
                    currentResponseResult = ResponseType.respondedWithPostpone.rawValue
                    utterSentence(line: "Ok. Remind you after five minutes");
                    setNotificationAfterSeconds(secs: 300)
                }
                else if (responseStr.contains("minute")){
                    currentResponseResult = ResponseType.respondedWithPostpone.rawValue
                    let wordsArr = responseStr.components(separatedBy: " ")
                    var indexOfMin: Int = 0
                    for (idx, str) in wordsArr.enumerated(){
                        if(str.contains("minute")){
                            indexOfMin = idx - 1
                            break
                        }
                    }
                    if(indexOfMin >= 0){
                        if(CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: wordsArr[indexOfMin]))){
                            let mn: Int = Int(wordsArr[indexOfMin])!
                            utterSentence(line: "Ok. Remind you after \(mn) minutes");
                            setNotificationAfterSeconds(secs: mn*60)
                        } else{
                            let mn: Int = HelperMethods.wordToNumber(word: wordsArr[indexOfMin])//2  //extensiveLater
                            utterSentence(line: "Ok. Remind you after \(mn) minutes");
                            setNotificationAfterSeconds(secs: mn*60)
                        }
                    }
                } else if (responseStr.contains("thank")){ //"thanks for reminding" type response
                    conversationFinished = true //currentResponseResult unchnaged
                    utterSentence(line: "You are welcome.")
                }
            }
            else if (responseStr.contains("thank")){
                conversationFinished = true //currentResponseResult unchnaged
                utterSentence(line: "You are welcome.")
            } else if(responseStr.contains("ok")||responseStr.contains("ll do") || responseStr.contains("ll check") || responseStr.contains("ll take")){
                currentResponseResult = ResponseType.respondedWithConfirmedTaking.rawValue
                conversationFinished = true
                utterSentence(line: "Ok. Thank you.")
            }
            else{
                //said other than keywords, what now? //currentResponseResult unchnaged
                conversationFinished = true
                //thank you??
            }
        }else{
            //said nothing, pressed done, what now? //currentResponseResult unchnaged
            conversationFinished = true
        }
        if(conversationFinished == true){
            //this 5sec is not important,conversationFinished does everything, but overall click/start talking has to be started within 40 secs mentioned in notifcontroller
        }
    }
    
    public func loadAlarm() {
        currentResponseText = ""
        conversationFinished = false
        currentResponseResult = ResponseType.clicked.rawValue
        let query:String = "Time to wash your hands"
        DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
            self.utterSentence(line: query)
        })
    }
    //==============///
    @IBAction func ScanAction() {
        startBeaconSensingAndRemind()
    }
    
    @IBAction func StopScan() {
        keepAlivetimer?.invalidate()
        centralManager.stopScan()
    }
    
    @IBAction func HWStartAction() {
        startTime = Double(Date().millisecondsSince1970/1000)
        startCollectIMU()
    }
    
    @IBAction func HWEndAction() {
        WKInterfaceDevice.current().play(.success)
        WKInterfaceDevice.current().play(.click)
        endTime = Double(Date().millisecondsSince1970/1000)
        workoutManager.stopWorkout()
        getDataAndProcessInModel()
        callformalAndFeedback()
    }
    
    @IBAction func ShowResults() {
        print("ShowResults: ", resultsArray)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            let thisService = service as CBService
            peripheral.discoverCharacteristics(nil, for: thisService)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            self.peripheral.setNotifyValue(true, for: thisCharacteristic)
        }
    }
    
    func getDocumentsHWDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataPath = documentsDirectory.appendingPathComponent("HW")
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do { //try to create HW folder inside document directory if not exists, and return HW folder
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                print("Error creating directory: \(error.localizedDescription)")
            }
        }
        return dataPath
    }
    
    func writeStringtoWatchFile(str: String, filename: String){ //+.txt create a file with filename in that directory if not exists (tested in datacollection app) and write a line at start
        let filename = getDocumentsHWDirectory().appendingPathComponent(filename)
        do {
            try str.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("ERROR in writeStringtoWatchFile")
        }
    }
    
    func appendStringtoWatchFile(str: String, filename: String){
        let filename = getDocumentsHWDirectory().appendingPathComponent(filename)
        do {
            let data = str.data(using: String.Encoding.utf8, allowLossyConversion: false)!
            let fileHandle = try FileHandle(forWritingTo: filename)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } catch {
            print("ERROR in appendStringtoWatchFile")
        }
    }
    
    func activateNotificationsOnWatch(){
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound,.alert]) { (granted, error) in
            if granted == false {
                print("Launch Notification Error: \(error?.localizedDescription)")
            }
        }
        let notificationCategory = UNNotificationCategory(identifier: "hw.category", actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([notificationCategory])
    }
    
    func setNotificationAfterSeconds(secs: Int){
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secs), repeats: false)
        addaReminderNotification(trigger: trigger) //test?
    }
    
    func addaReminderNotification(trigger: UNNotificationTrigger){
        let content = getNotificationContent()
        let uuId = HelperMethods.stringWithUUID()
        let request = UNNotificationRequest(identifier: uuId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (notificationError) in
            if(notificationError == nil){
            }
        }
    }
    
    func getNotificationContent() -> UNMutableNotificationContent{
        let content = UNMutableNotificationContent()
        content.title = "Washed"
        content.subtitle = "Wash your Hands!"
        content.body = "Wash"
        content.sound = UNNotificationSound.default//content.attachments = pillImageInNotification()
        //content.categoryIdentifier = "medicine.category"
        //content.userInfo = reminder as? NSDictionary as? [AnyHashable: Any] ?? [:]
        return content
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound,.alert])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {//clicked
        do {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        } catch {
        }
        completionHandler()
        loadAlarm()
    }
    
    public enum ResponseType: Int {
        case noResponse = 0
        case notified = 1
        case clicked = 2
        case respondedNotUnderstood = 3
        case respondedWithStop = 4
        case respondedWithPostpone = 5 //count as accept later
        case respondedWithConfirmedTaking = 6
        case respondedWithAskedDetails = 7
        case respondedWithRepeat = 8
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if(conversationFinished == false){
            self.currentResponseText = ""
            InitiateDictation(textChoices:[])
        }
    }
    
    func utterSentence(line: String ){
        synth = AVSpeechSynthesizer()
        myUtterance = AVSpeechUtterance(string: line)
        synth?.delegate = self
        myUtterance.rate = 0.5
        synth?.speak(myUtterance)
    }
    
    func InitiateDictation(textChoices: [String]){
        presentTextInputController(withSuggestions: textChoices, allowedInputMode:WKTextInputMode.plain, completion: {(results) -> Void in
            if results != nil && results!.count > 0 {
                self.currentResponseText = (results?[0] as? String)!
                self.handleFirstResponse()
            }
        })
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        workoutManager.delegate = self
        activateNotificationsOnWatch()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}

extension Array where Element: FloatingPoint {
    
    func sum() -> Element {
        return self.reduce(0, +)
    }
    
    func avg() -> Element {
        return self.sum() / Element(self.count)
    }
    
    func std() -> Element {
        let mean = self.avg()
        let v = self.reduce(0, { $0 + ($1-mean)*($1-mean) })
        return sqrt(v / (Element(self.count) - 1))
    }
    
}
