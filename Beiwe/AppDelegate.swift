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
import ResearchKit;
import PermissionScope

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var storyboard: UIStoryboard?;
    var modelVersionId = "";
    let motionManager = CMMotionManager();
    var reachability: Reachability?;
    var currentRootView: String? = "launchScreen";
    var isLoggedIn: Bool = false;
    var timeEnteredBackground: NSDate?;
    let pscope = PermissionScope()

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        Fabric.with([Crashlytics.self])
        pscope.addPermission(NotificationsPermission(notificationCategories: nil),
                             message: "Allows us to send you survey notifications")
        pscope.addPermission(LocationAlwaysPermission(),
                             message: "We need this for the data gathering capabilities of the application")

        do {
            reachability = try Reachability.reachabilityForInternetConnection()
            try reachability!.startNotifier()
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

        /* Colors */

        UIView.appearance().tintColor = UIColor(1, g: 64, b: 64, a: 1);

        storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle());

        self.window = UIWindow(frame: UIScreen.mainScreen().bounds);
        self.window?.rootViewController = UIStoryboard(name: "LaunchScreen", bundle: NSBundle.mainBundle()).instantiateViewControllerWithIdentifier("launchScreen");
        self.window!.makeKeyAndVisible()

        Recline.shared.open().then { _ -> Promise<Bool> in
            print("Database opened");
            return StudyManager.sharedInstance.loadDefaultStudy();
            }.then { _ -> Void in
                self.transitionToCurrentAppState();
            }.error { err -> Void in
                print("Database open failed.");
        }
        //launchScreen
        /*
            //self.window!.backgroundColor = UIColor.whiteColor()

            self.window?.rootViewController = OnboardViewController();



        }
        */


        return true
    }

    func changeRootViewControllerWithIdentifier(identifier:String!) {
        if (identifier == currentRootView) {
            return;
        }
        let desiredViewController:UIViewController = (self.storyboard?.instantiateViewControllerWithIdentifier(identifier))!;

        changeRootViewController(desiredViewController, identifier: identifier);
    }

    func changeRootViewController(desiredViewController: UIViewController, identifier: String? = nil) {
        currentRootView = identifier;

        let snapshot:UIView = (self.window?.snapshotViewAfterScreenUpdates(true))!
        desiredViewController.view.addSubview(snapshot);

        self.window?.rootViewController = desiredViewController;

        UIView.animateWithDuration(0.3, animations: {() in
            snapshot.layer.opacity = 0;
            snapshot.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5);
            }, completion: {
                (value: Bool) in
                snapshot.removeFromSuperview();
        });
    }

    func transitionToCurrentAppState() {


        if let currentStudy = StudyManager.sharedInstance.currentStudy {
            if (currentStudy.participantConsented) {
                StudyManager.sharedInstance.startStudyDataServices();
            }
            if (!isLoggedIn) {
                // Load up the log in view
                changeRootViewControllerWithIdentifier("login");
            } else {
                // We are logged in, so if we've completed onboarding load main interface
                // Otherwise continue onboarding.
                if (currentStudy.participantConsented) {
                    changeRootViewControllerWithIdentifier("mainView");
                } else {
                    changeRootViewController(ConsentManager().consentViewController);
                }

            }

        } else {
            // If there is no study loaded, then it's obvious.  We need the onboarding flow
            // from the beginning.
            changeRootViewController(OnboardingManager().onboardingViewController);
        }
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
        timeEnteredBackground = NSDate();

    }

    func checkPasswordAndLogin(password: String) -> Bool {
        if let storedPassword = PersistentPasswordManager.sharedInstance.passwordForStudy() where storedPassword.characters.count > 0 {
            if (password == storedPassword) {
                isLoggedIn = true;
                return true;
            }

        }

        return false;

    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        print("ApplicationWillEnterForeground");
        if let timeEnteredBackground = timeEnteredBackground, currentStudy = StudyManager.sharedInstance.currentStudy, studySettings = currentStudy.studySettings where isLoggedIn == true {
            let loginExpires = timeEnteredBackground.dateByAddingTimeInterval(Double(studySettings.secondsBeforeAutoLogout * 1000));
            if (loginExpires.compare(NSDate()) == NSComparisonResult.OrderedAscending) {
                // expired.  Log 'em out
                isLoggedIn = false;
                transitionToCurrentAppState();
            }
        } else {
            isLoggedIn = false;
        }
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

