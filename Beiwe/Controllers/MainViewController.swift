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

class MainViewController: UIViewController, ORKTaskViewControllerDelegate {

    var listeners: [Listener] = [];
    var taskListController: TaskListViewController?;
    var hakuba: Hakuba!;

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
        self.navigationItem.rightBarButtonItem = nil;

        // Do any additional setup after loading the view.

        hakuba = Hakuba(tableView: surveyTableView);
        surveyTableView.backgroundView = nil;
        surveyTableView.backgroundColor = UIColor.clearColor();
        /*hakuba
            .registerCell(SurveyCell) */

        listeners += StudyManager.sharedInstance.surveysUpdatedEvent.on { [weak self] in
            self?.refreshSurveys();
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
                }
            }
            hakuba[0].bump();
        }

    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

        confirmAndCallClinician();
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

    func presentTrackingSurvey(surveyId: String, activeSurvey: ActiveSurvey, survey: Survey) {
        var steps = [ORKStep]();

        let instructionStep = ORKInstructionStep(identifier: "instruction");
        instructionStep.title = "Give some basic instructions";
        instructionStep.text = "Do your best!";
        steps += [instructionStep];

        let ageAnswerFormat = ORKAnswerFormat.integerAnswerFormatWithUnit("Age");
        ageAnswerFormat.minimum = 18;
        ageAnswerFormat.maximum = 90;
        let ageStep = ORKQuestionStep(identifier: "age", title: "How old are you?", answer: ageAnswerFormat);
        steps += [ageStep];

        let summaryStep = ORKInstructionStep(identifier: "Summary");
        summaryStep.title = "Survey complete!";
        summaryStep.text = "This is a standard researchkit element, but we could just pop up our own completion UI";
        steps += [summaryStep];


        let task = ORKOrderedTask(identifier: "SurveyTask", steps: steps)
        let surveyViewController = ORKTaskViewController(task: task, taskRunUUID: nil);
        surveyViewController.showsProgressInNavigationBar = false;
        surveyViewController.delegate = self;

        presentViewController(surveyViewController, animated: true, completion: nil)
        
    }


    func presentSurvey(surveyId: String) {
        guard let activeSurvey = StudyManager.sharedInstance.currentStudy?.activeSurveys[surveyId], survey = activeSurvey.survey, surveyType = survey.surveyType else {
            return;
        }

        switch(surveyType) {
        case .TrackingSurvey:
            TrackingSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey).present(self);
        case .AudioSurvey:
            AudioSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey).present(self);
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
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    /* ORK Delegates */
    func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)

        self.dismissViewControllerAnimated(true, completion: nil);
        print("Finished.");
    }

    func taskViewController(taskViewController: ORKTaskViewController, didChangeResult result: ORKTaskResult) {

        return;
    }

    func taskViewController(taskViewController: ORKTaskViewController, shouldPresentStep step: ORKStep) -> Bool {
        return true;
    }

    func taskViewController(taskViewController: ORKTaskViewController, learnMoreForStep stepViewController: ORKStepViewController) {
        // Present modal...
        let refreshAlert = UIAlertController(title: "Learning more!", message: "You're smart now", preferredStyle: UIAlertControllerStyle.Alert)

        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: { (action: UIAlertAction!) in
            print("Handle Ok logic here")
        }))


        taskViewController.presentViewController(refreshAlert, animated: true, completion: nil)
    }

    func taskViewController(taskViewController: ORKTaskViewController, hasLearnMoreForStep step: ORKStep) -> Bool {
        return true;
    }

    func taskViewController(taskViewController: ORKTaskViewController, viewControllerForStep step: ORKStep) -> ORKStepViewController? {
        return nil;
    }

    func taskViewController(taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        print("Step will appear;");

        //stepViewController.continueButtonTitle = "Go!"
    }


}
