//
//  AppDelegate.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/10/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import PromiseKit
import CoreMotion;
import ReachabilitySwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var storyboard: UIStoryboard?;
    var modelVersionId = "";
    let motionManager = CMMotionManager();
    var reachability: Reachability?;


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        let reachability: Reachability
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
            try reachability.startNotifier()
        } catch {
            print("Unable to create or start Reachability")
        }
        print("AppUUID: \(PersistentAppUUID.sharedInstance.uuid)");
        let uiDevice = UIDevice.currentDevice();
        modelVersionId = UIDevice.currentDevice().model + "/" + UIDevice.currentDevice().systemVersion;
        print("name: \(uiDevice.name)");
        print("systemName: \(uiDevice.systemName)");
        print("systemVersion: \(uiDevice.systemVersion)");
        print("model: \(uiDevice.model)");
        print("platform: \(platform())");

        storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle());

        Recline.shared.open().then { _ -> Void in
            print("Database opened");
            StudyManager.sharedInstance.loadDefaultStudy();
        }.error { err -> Void in
            print("Database open failed.");
        }

        return true
    }

    static func sharedInstance() -> AppDelegate{
        return UIApplication.sharedApplication().delegate as! AppDelegate
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func displayCurrentMainView() {
        //

        var view: String;
        if let _ = StudyManager.sharedInstance.currentStudy {
            view = "initialStudyView";
        } else {
            view = "registerView";
        }
        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        //self.window!.backgroundColor = UIColor.whiteColor()

        self.window?.rootViewController = storyboard!.instantiateViewControllerWithIdentifier(view) as UIViewController!;

        self.window!.makeKeyAndVisible()
        
    }

    func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {

        return true;

    }

    func applicationProtectedDataDidBecomeAvailable(application: UIApplication) {
        print("applicationProtectedDataDidBecomeAvailable");
    }

    func applicationProtectedDataWillBecomeUnavailable(application: UIApplication) {
        print("applicationProtectedDataWillBecomeUnavailable");
    }
    /* Crashlytics functions -- future */

    func setDebuggingUser(username: String) {
        // TODO: Use the current user's information
        // You can call any combination of these three methods
        //Crashlytics.sharedInstance().setUserEmail("user@fabric.io")
        Crashlytics.sharedInstance().setUserIdentifier(username);
        //Crashlytics.sharedInstance().setUserName("Test User")
    }

    func crash() {
        Crashlytics.sharedInstance().crash()
    }



}

