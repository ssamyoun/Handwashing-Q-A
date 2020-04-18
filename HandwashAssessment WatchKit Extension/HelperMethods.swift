//
//  HelperMethods.swift
//  HandwashApp WatchKit Extension
//
//  Created by Sirat Samyoun on 11/13/19.
//  Copyright © 2019 Sirat Samyoun. All rights reserved.
//

import Foundation

class HelperMethods {
    
    static func stringWithUUID() -> String {
        let uuidObj = CFUUIDCreate(nil)
        let uuidString = CFUUIDCreateString(nil, uuidObj)!
        return uuidString as String
    }
    
    static func currentDateAmPmAsString() -> String{
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let outputString = dateFormatter.string(from: Date())
        return outputString
    }
    
    static func wordToNumber(word:String) -> Int{
        switch word
        {
        case "one": return 1
        case "an": return 1
        case "two": return 2
        case "three": return 3
        case "four": return 4
        case "five": return 5
        case "six": return 6
        case "seven": return 7
        case "eight": return 8
        case "nine": return 9
        case "ten": return 10
        case "eleven": return 11
        case "twelve": return 12
        case "thirteen": return 13
        case "fourteen": return 14
        case "fifteen": return 15
        case "sixteen": return 16
        case "seventeen": return 17
        case "eighteen": return 18
        case "nineteen": return 19
        case "twenty": return 20
        case "thirty": return 30
        case "fourty": return 40
        case "fifty": return 50
        case "sixty": return 60
        default: return 5
        }
    }
    
    static func sendToServer(uploadData:NSData){
        let strId = "randStr" + String(Int.random(in: 0..<100))
        print(strId)
        let configuration = URLSessionConfiguration.background(withIdentifier: strId)
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration)
        //let session = URLSession.shared
        let url = URL(string: "http://ec2-18-188-221-234.us-east-2.compute.amazonaws.com:3000/")!
        //let url = URL(string: "http://172.26.134.250:3000")!
        //let url = URL(string: "http://ptsv2.com/t/c1qas-1568855207/post")! ///t/c1qas-1568855207/post
        dataTaskFromURL(url: url, uploadData: uploadData, session: session)
    }
    //changed nsdata to calling function,was data, set content-lenght- can revert,Approach1 can revert
    //&also changed to backfround instead default--Approach 2,can revert
    static func dataTaskFromURL(url: URL, uploadData:NSData, session: URLSession){
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(uploadData.length)", forHTTPHeaderField: "Content-Length")
        request.httpBody = uploadData as Data
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            if error != nil {
                print("error=\(error)")
                return
            }
            print((response as? HTTPURLResponse)?.statusCode)
        }
        task.resume()
    }
    
}
