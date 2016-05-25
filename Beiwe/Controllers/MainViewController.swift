//
//  MainViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/30/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import ResearchKit
import EmitterKit
import Hakuba
import XLActionController

class MainViewController: UIViewController {

    var listeners: [Listener] = [];
    var hakuba: Hakuba!;
    var selectedSurvey: ActiveSurvey?

    @IBOutlet weak var callClinicianButton: UIButton!
    @IBOutlet weak var footerSeperator: UIView!
    @IBOutlet weak var activeSurveyHeader: UIView!
    @IBOutlet var emptySurveyHeader: UIView!
    @IBOutlet weak var surveyTableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.presentTransparentNavigationBar();
        let leftImage : UIImage? = UIImage(named:"ic-user")!.imageWithRenderingMode(.AlwaysOriginal);
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftImage, style: UIBarButtonItemStyle.Plain, target: self, action: #selector(userButton))
        /*
        let rightImage : UIImage? = UIImage(named:"ic-info")!.imageWithRenderingMode(.AlwaysOriginal);
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: rightImage, style: UIBarButtonItemStyle.Plain, target: self, action: #selector(infoButton))
        */
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationItem.rightBarButtonItem = nil;

        // Do any additional setup after loading the view.

        hakuba = Hakuba(tableView: surveyTableView);
        surveyTableView.backgroundView = nil;
        surveyTableView.backgroundColor = UIColor.clearColor();
        /*hakuba
            .registerCell(SurveyCell) */

        var clinicianText: String;
        clinicianText = StudyManager.sharedInstance.currentStudy?.studySettings?.callClinicianText ?? "Contact Clinician"
        callClinicianButton.setTitle(clinicianText, forState: UIControlState.Normal)
        callClinicianButton.setTitle(clinicianText, forState: UIControlState.Highlighted)
        if #available(iOS 9.0, *) {
            callClinicianButton.setTitle(clinicianText, forState: UIControlState.Focused)
        } else {
            // Fallback on earlier versions
        }
        listeners += StudyManager.sharedInstance.surveysUpdatedEvent.on { [weak self] in
            self?.refreshSurveys();
        }

        if (AppDelegate.sharedInstance().debugEnabled) {
            addDebugMenu();
        }

        refreshSurveys();

    }

    func refreshSurveys() {
        hakuba.removeAll();
        let section = Section() // create a new section

        hakuba
            .insert(section, atIndex: 0)
            .bump()

        var cnt = 0;
        if let activeSurveys = StudyManager.sharedInstance.currentStudy?.activeSurveys {
            let sortedSurveys = activeSurveys.sort { (s1, s2) -> Bool in
                return s1.1.received > s2.1.received;
            }

            for (_,survey) in sortedSurveys {
                if (!survey.isComplete) {
                    let cellmodel = SurveyCellModel(activeSurvey: survey) { [weak self] cell in
                        cell.selected = false;
                        if let strongSelf = self, surveyCell = cell as? SurveyCell, surveyId = surveyCell.cellmodel?.activeSurvey.survey?.surveyId {
                            strongSelf.presentSurvey(surveyId)
                        }
                    }
                    hakuba[0].append(cellmodel)
                    cnt += 1;
                }
            }
            hakuba[0].bump();
        }
        if (cnt > 0) {
            footerSeperator.hidden = false
            surveyTableView.tableHeaderView = activeSurveyHeader;
            surveyTableView.scrollEnabled = true
        } else {
            footerSeperator.hidden = true
            surveyTableView.tableHeaderView = emptySurveyHeader;
            surveyTableView.scrollEnabled = false
        }

    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func addDebugMenu() {

        let tapRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(debugTap))
        tapRecognizer.numberOfTapsRequired = 2;
        tapRecognizer.numberOfTouchesRequired = 2;
        self.view.addGestureRecognizer(tapRecognizer)
    }

    func debugTap(gestureRecognizer: UIGestureRecognizer) {
        if (gestureRecognizer.state != .Ended) {
            return
        }

        let actionController = BWXLActionController()
        actionController.settings.cancelView.backgroundColor = AppColors.highlightColor

        actionController.headerData = nil;

        actionController.addAction(Action(ActionData(title: "Upload Data"), style: .Default) { (action) in
            dispatch_async(dispatch_get_main_queue()) {
                self.Upload(self)
            }
            });
        actionController.addAction(Action(ActionData(title: "Check for Surveys"), style: .Default) { (action) in
            dispatch_async(dispatch_get_main_queue()) {
                self.checkSurveys(self)
            }

            });

        self.presentViewController(actionController, animated: true) {

        }
        
        

    }
    func userButton() {
        /*
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)

        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel) { (action) in
            // ...
            });

        alertController.addAction(UIAlertAction(title: "Change Password", style: .Default) { (action) in
            self.changePassword(self)
            });

        alertController.addAction(UIAlertAction(title: "Logout", style: .Default) { (action) in
            self.logout(self);
            });

        alertController.addAction(UIAlertAction(title: "Leave Study", style: .Destructive) { (action) in
            self.leaveStudy(self);
            });

        self.presentViewController(alertController, animated: true) {
            // ...
        }
        */

        let actionController = BWXLActionController()
        actionController.settings.cancelView.backgroundColor = AppColors.highlightColor

        actionController.headerData = nil;

        actionController.addAction(Action(ActionData(title: "Change Password"), style: .Default) { (action) in
            dispatch_async(dispatch_get_main_queue()) {
                self.changePassword(self);
            }
            });
        actionController.addAction(Action(ActionData(title: "Logout"), style: .Default) { (action) in
            dispatch_async(dispatch_get_main_queue()) {
                self.logout(self);
            }

            });
        actionController.addAction(Action(ActionData(title: "Leave Study"), style: .Destructive) { (action) in
            dispatch_async(dispatch_get_main_queue()) {
                self.leaveStudy(self);
            }
            });

        self.presentViewController(actionController, animated: true) {
            
        }



    }

    func infoButton() {

    }
    
    @IBAction func Upload(sender: AnyObject) {
        StudyManager.sharedInstance.upload();
    }


    @IBAction func callClinician(sender: AnyObject) {
        // Present modal...

        confirmAndCallClinician(self);
    }

    @IBAction func checkSurveys(sender: AnyObject) {
        StudyManager.sharedInstance.checkSurveys();
    }
    @IBAction func leaveStudy(sender: AnyObject) {
        let alertController = UIAlertController(title: "Leave Study", message: "Are you sure you want to leave the current study?", preferredStyle: .Alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) in
            print("Cancelled leave.")
        }
        alertController.addAction(cancelAction)

        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
            StudyManager.sharedInstance.leaveStudy().then {_ -> Void in
                AppDelegate.sharedInstance().isLoggedIn = false;
                AppDelegate.sharedInstance().transitionToCurrentAppState();
            }
        }
        alertController.addAction(OKAction)
        
        self.presentViewController(alertController, animated: true) {
            print("Ok");
        }
    }

    func presentSurvey(surveyId: String) {
        guard let activeSurvey = StudyManager.sharedInstance.currentStudy?.activeSurveys[surveyId], survey = activeSurvey.survey, surveyType = survey.surveyType else {
            return;
        }

        switch(surveyType) {
        case .TrackingSurvey:
            TrackingSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey).present(self);
        case .AudioSurvey:
            selectedSurvey = activeSurvey
            performSegueWithIdentifier("audioQuestionSegue", sender: self)
            //AudioSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey).present(self);
        }
    }


    @IBAction func changePassword(sender: AnyObject) {
        let changePasswordController = ChangePasswordViewController();
        changePasswordController.isForgotPassword = false;
        presentViewController(changePasswordController, animated: true, completion: nil);
    }
    @IBAction func logout(sender: AnyObject) {
        AppDelegate.sharedInstance().isLoggedIn = false;
        AppDelegate.sharedInstance().transitionToCurrentAppState();
    }
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if (segue.identifier == "audioQuestionSegue") {
            let questionController: AudioQuestionViewController = segue.destinationViewController as! AudioQuestionViewController
            questionController.activeSurvey = selectedSurvey
        }
    }



}
