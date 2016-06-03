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
import XCGLogger

let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

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
    var canOpenTel = false;
    let debugEnabled  = _isDebugAssertConfiguration();

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        Fabric.with([Crashlytics.self])

        // Create a destination for the system console log (via NSLog)
        let systemLogDestination = XCGNSLogDestination(owner: log, identifier: "advancedLogger.systemLogDestination")

        // Optionally set some configuration options
        systemLogDestination.outputLogLevel = debugEnabled ? .Debug : .Warning
        systemLogDestination.showLogIdentifier = false
        systemLogDestination.showFunctionName = false // true
        systemLogDestination.showThreadName = true
        systemLogDestination.showLogLevel = false // true
        systemLogDestination.showFileName = false // true
        systemLogDestination.showLineNumber = false // true
        systemLogDestination.showDate = true
        
        // Add the destination to the logger
        log.addLogDestination(systemLogDestination)

        let crashlyticsLogDestination = XCGCrashlyticsLogDestination(owner: log, identifier: "advancedlogger.crashlyticsDestination")
        crashlyticsLogDestination.outputLogLevel = .Debug
        crashlyticsLogDestination.showLogIdentifier = false
        crashlyticsLogDestination.showFunctionName = false // true
        crashlyticsLogDestination.showThreadName = true
        crashlyticsLogDestination.showLogLevel = false // true
        crashlyticsLogDestination.showFileName = false // true
        crashlyticsLogDestination.showLineNumber = false // true
        crashlyticsLogDestination.showDate = true

        // Add the destination to the logger
        log.addLogDestination(crashlyticsLogDestination)


        log.info("applicationDidFinishLaunching")
        log.logAppDetails()

        pscope.addPermission(NotificationsPermission(notificationCategories: nil),
                             message: "Allows us to send you survey notifications")
        pscope.addPermission(LocationAlwaysPermission(),
                             message: "We need this for the data gathering capabilities of the application")

        do {
            reachability = try Reachability.reachabilityForInternetConnection()
            try reachability!.startNotifier()
        } catch {
            log.error("Unable to create or start Reachability")
        }
        log.info("AppUUID: \(PersistentAppUUID.sharedInstance.uuid)");
        let uiDevice = UIDevice.currentDevice();
        modelVersionId = UIDevice.currentDevice().model + "/" + UIDevice.currentDevice().systemVersion;
        log.info("name: \(uiDevice.name)");
        log.info("systemName: \(uiDevice.systemName)");
        log.info("systemVersion: \(uiDevice.systemVersion)");
        log.info("model: \(uiDevice.model)");
        log.info("platform: \(platform())");

        canOpenTel = UIApplication.sharedApplication().canOpenURL(NSURL(string: "tel:6175551212")!);


        /* Colors */

        let rkAppearance = UIView.my_appearanceWhenContainedIn(ORKTaskViewController.self)
        rkAppearance.tintColor = AppColors.tintColor;
        //rkAppearance.backgroundColor = UIColor.clearColor() // AppColors.gradientBottom;

        /*
        let stepAppearance = UIView.my_appearanceWhenContainedIn(ORKStepViewController.self)
        stepAppearance.tintColor = AppColors.tintColor;
        stepAppearance.backgroundColor = UIColor.clearColor() // AppColors.gradientBottom;
        */

        /*
        UIView.appearanceWhenContainedInInstancesOfClasses([ORKTaskViewController.self]).tintColor = AppColors.tintColor
        */

        //UIView.appearance().tintColor = AppColors.tintColor;

        storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle());

        self.window = UIWindow(frame: UIScreen.mainScreen().bounds);
        self.window?.rootViewController = UIStoryboard(name: "LaunchScreen", bundle: NSBundle.mainBundle()).instantiateViewControllerWithIdentifier("launchScreen");
        /* Gradient background so we can use "clear" RK views */
        /*
        let backView = GradientView(frame: UIScreen.mainScreen().bounds)
        backView.topColor = AppColors.gradientBottom
        backView.bottomColor = UIColor.whiteColor()
        self.window?.insertSubview(backView, atIndex: 0)
        */
        

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
        log.info("applicationWillResignActive")
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        log.info("applicationDidEnterBackground")
        timeEnteredBackground = NSDate();

    }

    func checkPasswordAndLogin(password: String) -> Bool {
        if let storedPassword = PersistentPasswordManager.sharedInstance.passwordForStudy() where storedPassword.characters.count > 0 {
            if (password == storedPassword) {
                ApiManager.sharedInstance.password = storedPassword;
                isLoggedIn = true;
                return true;
            }

        }

        return false;

    }

    func applicationWillEnterForeground(application: UIApplication) {
        log.info("applicationWillEnterForeground")
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
        log.info("applicationDidBecomeActive")
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        log.info("applicationWillTerminate")
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
        log.info("applicationWillFinishLaunchingWithOptions")
        return true;

    }

    func applicationProtectedDataDidBecomeAvailable(application: UIApplication) {
        log.info("applicationProtectedDataDidBecomeAvailable");
    }

    func applicationProtectedDataWillBecomeUnavailable(application: UIApplication) {
        log.info("applicationProtectedDataWillBecomeUnavailable");
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

