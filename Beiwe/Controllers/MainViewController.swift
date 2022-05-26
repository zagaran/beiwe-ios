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
import XLActionController
import Sentry

class MainViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var listeners: [Listener] = [];
    var selectedSurvey: ActiveSurvey?

    let cellReuseIdentifier = "cell"

    @IBOutlet weak var haveAQuestionLabel: UILabel!
    @IBOutlet weak var callClinicianButton: UIButton!
    @IBOutlet weak var footerSeperator: UIView!
    @IBOutlet weak var surveysAndMessagesTableView: UITableView!
    
    struct TableData {
        var messages: [String]
        var surveys: [ActiveSurvey]
    }

    var tableData = TableData(messages: [], surveys: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.presentTransparentNavigationBar();
        let leftImage : UIImage? = UIImage(named:"ic-user")!.withRenderingMode(.alwaysOriginal);
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftImage, style: UIBarButtonItem.Style.plain, target: self, action: #selector(userButton))
        /*
        let rightImage : UIImage? = UIImage(named:"ic-info")!.imageWithRenderingMode(.AlwaysOriginal);
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: rightImage, style: UIBarButtonItemStyle.Plain, target: self, action: #selector(infoButton))
        */
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationItem.rightBarButtonItem = nil;

        // Do any additional setup after loading the view.
        self.surveysAndMessagesTableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)

        surveysAndMessagesTableView.delegate = self
        surveysAndMessagesTableView.dataSource = self
        surveysAndMessagesTableView.backgroundView = nil;
        surveysAndMessagesTableView.backgroundColor = UIColor.clear;

        var clinicianText: String;
        clinicianText = StudyManager.sharedInstance.currentStudy?.studySettings?.callClinicianText ?? NSLocalizedString("default_call_clinician_text", comment: "")
        callClinicianButton.setTitle(clinicianText, for: UIControl.State())
        callClinicianButton.setTitle(clinicianText, for: UIControl.State.highlighted)
        if #available(iOS 9.0, *) {
            callClinicianButton.setTitle(clinicianText, for: UIControl.State.focused)
        }
        
        // Hide call button if it's disabled in the study settings
        if !(StudyManager.sharedInstance.currentStudy?.studySettings?.callClinicianButtonEnabled)! {
            haveAQuestionLabel.isHidden = true
            callClinicianButton.isHidden = true
        }
        
        listeners += StudyManager.sharedInstance.surveysUpdatedEvent.on { [weak self] data in
            self?.reloadSurveysList();
        }
        listeners += StudyManager.sharedInstance.messagesUpdatedEvent.on { [weak self] data in
            self?.reloadMessagesList();
        }

        if (AppDelegate.sharedInstance().debugEnabled) {
            addDebugMenu();
        }

        reloadSurveysList()
        reloadMessagesList()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return self.tableData.messages.count
        } else if section == 1 {
            return self.tableData.surveys.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = self.surveysAndMessagesTableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            cell.textLabel?.text = self.tableData.messages[indexPath.row]
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SurveyCell", for: indexPath) as! SurveyCell
            let activeSurvey = self.tableData.surveys[indexPath.row]
            cell.configure(activeSurvey: activeSurvey)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            // Messages section header
            return "Messages"
        } else if section == 1 {
            // Surveys section header
            if self.tableData.surveys.count == 0 {
                return "Active Surveys: no active surveys"
            } else {
                return "Active Surveys"
            }
        } else {
            return ""
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 && self.tableData.messages.count == 0 {
            // If there are no messages, hide the "Messages" section header
            // because messages are a new feature
            return 0
        } else {
            return self.surveysAndMessagesTableView.sectionHeaderHeight
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            print("Selected a message row")
        } else if indexPath.section == 1 {
            let surveyId = self.tableData.surveys[indexPath.row].survey?.surveyId
            self.presentSurvey(surveyId!)
        }
    }
    
    func reloadMessagesList() {
        self.tableData.messages = StudyManager.sharedInstance.currentStudy?.messages ?? []
        self.surveysAndMessagesTableView.reloadSections([0], with: UITableView.RowAnimation.fade)
    }

    func reloadSurveysList() {
        self.tableData.surveys = []
        if let activeSurveys = StudyManager.sharedInstance.currentStudy?.activeSurveys {
            let sortedSurveys = activeSurveys.sorted { (s1, s2) -> Bool in
                return s1.1.received > s2.1.received;
            }

            // because surveys do not have their state cleared when the done button is pressed, the buttons retain
            // the incomplete label and tapping on a finished always available survey results in loading to the "done" buttton on that survey.
            // (and creating a new file. see comments in StudyManager.swift for explination of this behavior.)
            
            for (_,active_survey) in sortedSurveys {
                if (!active_survey.isComplete || active_survey.survey?.alwaysAvailable ?? false) {
                    self.tableData.surveys.append(active_survey)
                }
            }
        }
        self.surveysAndMessagesTableView.reloadSections([1], with: UITableView.RowAnimation.fade)
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

    @objc func debugTap(_ gestureRecognizer: UIGestureRecognizer) {
        if (gestureRecognizer.state != .ended) {
            return
        }

        reloadSurveysList();

        let actionController = BWXLActionController()
        actionController.settings.cancelView.backgroundColor = AppColors.highlightColor

        actionController.headerData = nil;

        actionController.addAction(Action(ActionData(title: NSLocalizedString("upload_data_button", comment: "")), style: .default) { (action) in
            DispatchQueue.main.async {
                self.Upload(self)
            }
            });
        actionController.addAction(Action(ActionData(title: NSLocalizedString("check_for_surveys_button", comment: "")), style: .default) { (action) in
            DispatchQueue.main.async {
                self.checkSurveys(self)
            }

            });

        self.present(actionController, animated: true) {

        }
    }
    
    @objc func userButton() {
        let actionController = BWXLActionController()
        actionController.settings.cancelView.backgroundColor = AppColors.highlightColor

        actionController.headerData = nil;

        actionController.addAction(Action(ActionData(title: NSLocalizedString("change_password_button", comment: "")), style: .default) { (action) in
            DispatchQueue.main.async {
                self.changePassword(self);
            }
        });
        
        // Only add Call button if it's enabled by the study
        if (StudyManager.sharedInstance.currentStudy?.studySettings?.callResearchAssistantButtonEnabled)! {
            actionController.addAction(Action(ActionData(title: NSLocalizedString("call_research_assistant_button", comment: "")), style: .default) { (action) in
                DispatchQueue.main.async {
                    confirmAndCallClinician(self, callAssistant: true)
                }
            });
        }
        
        actionController.addAction(Action(ActionData(title: NSLocalizedString("logout_button", comment: "")), style: .default) { (action) in
            DispatchQueue.main.async {
                self.logout(self);
            }

        });
        actionController.addAction(Action(ActionData(title: NSLocalizedString("unregister_button", comment: "")), style: .destructive) { (action) in
            DispatchQueue.main.async {
                self.leaveStudy(self);
            }
        });
        self.present(actionController, animated: true)
    }

    func infoButton() {

    }
    
    @IBAction func Upload(_ sender: AnyObject) {
        StudyManager.sharedInstance.upload(false);
    }


    @IBAction func callClinician(_ sender: AnyObject) {
        // Present modal...
        confirmAndCallClinician(self);
    }

    @IBAction func checkSurveys(_ sender: AnyObject) {
        StudyManager.sharedInstance.checkSurveys();
    }
    @IBAction func leaveStudy(_ sender: AnyObject) {
        let alertController = UIAlertController(title: NSLocalizedString("unregister_alert_title", comment: ""), message: NSLocalizedString("unregister_alert_text", comment: ""), preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel_button_text", comment: ""), style: .cancel) { (action) in
        }
        alertController.addAction(cancelAction)

        let OKAction = UIAlertAction(title: NSLocalizedString("ok_button_text", comment: ""), style: .default) { (action) in
            StudyManager.sharedInstance.leaveStudy().done {_ -> Void in
                AppDelegate.sharedInstance().isLoggedIn = false;
                AppDelegate.sharedInstance().transitionToCurrentAppState();
            }
        }
        alertController.addAction(OKAction)
        
        self.present(alertController, animated: true) {
        }
    }

    func presentSurvey(_ surveyId: String) {
        guard let activeSurvey = StudyManager.sharedInstance.currentStudy?.activeSurveys[surveyId], let survey = activeSurvey.survey, let surveyType = survey.surveyType else {
            return;
        }

        switch(surveyType) {
        case .TrackingSurvey:
            TrackingSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey).present(self);
        case .AudioSurvey:
            selectedSurvey = activeSurvey
            performSegue(withIdentifier: "audioQuestionSegue", sender: self)
            //AudioSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey).present(self);
        }
    }


    @IBAction func changePassword(_ sender: AnyObject) {
        let changePasswordController = ChangePasswordViewController();
        changePasswordController.isForgotPassword = false;
        present(changePasswordController, animated: true, completion: nil);
    }
    @IBAction func logout(_ sender: AnyObject) {
        AppDelegate.sharedInstance().isLoggedIn = false;
        AppDelegate.sharedInstance().transitionToCurrentAppState();
    }
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if (segue.identifier == "audioQuestionSegue") {
            let questionController: AudioQuestionViewController = segue.destination as! AudioQuestionViewController
            questionController.activeSurvey = selectedSurvey
        }
    }



}
