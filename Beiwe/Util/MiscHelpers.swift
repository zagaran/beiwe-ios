//
//  MiscHelpers.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/23/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

func platform() -> String {
    var size : Int = 0 // as Ben Stahl noticed in his answer
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](count: Int(size), repeatedValue: 0)
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    return String.fromCString(machine)!
}

func shuffle<C: MutableCollectionType where C.Index == Int>(inout list: C) -> C {
    let c = list.count
    if c < 2 { return list }
    for i in 0..<(c - 1) {
        let j = Int(arc4random_uniform(UInt32(c - i))) + i
        if i != j {
            swap(&list[i], &list[j])
        }
    }
    return list
}

let transformNSData = TransformOf<NSData, String>(fromJSON: { encoded in
    // transform value from String? to Int?
    if let str = encoded {
        return NSData(base64EncodedString: str, options: []);
    } else {
        return nil;
    }
    }, toJSON: { value -> String? in
        // transform value from Int? to String?
        if let value = value {
            return value.base64EncodedStringWithOptions([]);
        }
        return nil
})

let transformNotification = TransformOf<UILocalNotification, String>(fromJSON: { encoded -> UILocalNotification? in
    // transform value from String? to Int?
    if let str = encoded {
        let data = NSData(base64EncodedString: str, options: []);
        if let data = data {
            return NSKeyedUnarchiver.unarchiveObjectWithData(data) as! UILocalNotification?;
        }
    }
    return nil;
    }, toJSON: { value -> String? in
        // transform value from Int? to String?
        if let value = value {
            let data = NSKeyedArchiver.archivedDataWithRootObject(value);
            return data.base64EncodedStringWithOptions([]);
        }
        return nil
})

let transformJsonStringInt = TransformOf<Int, String>(fromJSON: { (value: String?) -> Int? in
    // transform value from String? to Int?
    guard let value = value else {
        return nil;
    }
    return Int(value)
    }, toJSON: { (value: Int?) -> String? in
        // transform value from Int? to String?
        if let value = value {
            return String(value)
        }
        return nil
})

class Debouncer<T>: NSObject {
    var arg: T?;
    var callback: ((arg: T?) -> ())
    var delay: Double
    weak var timer: NSTimer?

    init(delay: Double, callback: ((arg: T?) -> ())) {
        self.delay = delay
        self.callback = callback
    }

    func call(arg: T?) {
        self.arg = arg;
        if (delay == 0) {
            fireNow();
        } else {
            timer?.invalidate()
            let nextTimer = NSTimer.scheduledTimerWithTimeInterval(delay, target: self, selector: #selector(fireNow), userInfo: nil, repeats: false)
            timer = nextTimer
        }
    }

    func flush() {
        if let timer = timer {
            timer.invalidate();
            fireNow();
        }
    }

    func fireNow() {
        timer = nil;
        self.callback(arg: arg)
    }
}

func confirmAndCallClinician() {
    if let phoneNumber = StudyManager.sharedInstance.currentStudy?.clinicianPhoneNumber where AppDelegate.sharedInstance().canOpenTel {
        if let phoneUrl = NSURL(string: "tel:" + phoneNumber) {
            let callAlert = UIAlertController(title: "Confirm", message: "Are you sure you wish to call your primary clincian now?", preferredStyle: UIAlertControllerStyle.Alert)

            callAlert.addAction(UIAlertAction(title: "Ok", style: .Default) { (action: UIAlertAction!) in
                UIApplication.sharedApplication().openURL(phoneUrl)
                })
            callAlert.addAction(UIAlertAction(title: "Cancel", style: .Default) { (action: UIAlertAction!) in
                print("Call cancelled.");
                })
        }
    }
}