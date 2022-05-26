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
import Sentry

class MainViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var listeners: [Listener] = [];
    var hakuba: Hakuba!;
    var selectedSurvey: ActiveSurvey?

    let cellReuseIdentifier = "cell"

    @IBOutlet weak var haveAQuestionLabel: UILabel!
    @IBOutlet weak var callClinicianButton: UIButton!
    @IBOutlet weak var footerSeperator: UIView!
    @IBOutlet var activeSurveyHeader: UIView!
    @IBOutlet var emptySurveyHeader: UIView!
    @IBOutlet weak var surveysAndMessagesTableView: UITableView!
    
    struct TableSectionData {
        var title: String
        var items: [String]
    }
    
    struct TableData {
        var sections: [TableSectionData]
    }

    let listOfMessages = TableSectionData(title: "Messages", items: ["Message 1", "Message 2"])
    var listOfSurveys = TableSectionData(title: "Active Surveys", items: [])
    var surveysAndMessageTableData = TableData(sections: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.surveysAndMessageTableData = TableData(sections: [listOfMessages, listOfSurveys])
        
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

        // hakuba = Hakuba(tableView: surveyTableView);

        self.surveysAndMessagesTableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)

        surveysAndMessagesTableView.delegate = self
        surveysAndMessagesTableView.dataSource = self
        surveysAndMessagesTableView.backgroundView = nil;
        surveysAndMessagesTableView.backgroundColor = UIColor.clear;
        /*hakuba
            .registerCell(SurveyCell) */

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

        if (AppDelegate.sharedInstance().debugEnabled) {
            addDebugMenu();
        }

        reloadSurveysList();

    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.surveysAndMessageTableData.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.surveysAndMessageTableData.sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.surveysAndMessagesTableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
          
        cell.textLabel?.text = self.surveysAndMessageTableData.sections[indexPath.section].items[indexPath.row]
          
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.surveysAndMessageTableData.sections[section].title
    }
    
    func reloadSurveysList() {
        self.listOfSurveys.items = []
        if let activeSurveys = StudyManager.sharedInstance.currentStudy?.activeSurveys {
            let sortedSurveys = activeSurveys.sorted { (s1, s2) -> Bool in
                return s1.1.received > s2.1.received;
            }

            // because surveys do not have their state cleared when the done button is pressed, the buttons retain
            // the incomplete label and tapping on a finished always available survey results in loading to the "done" buttton on that survey.
            // (and creating a new file. see comments in StudyManager.swift for explination of this behavior.)
            
            for (_,active_survey) in sortedSurveys {
                if (!active_survey.isComplete || active_survey.survey?.alwaysAvailable ?? false) {
                    self.listOfSurveys.items.append((active_survey.survey?.surveyId)!)
                }
            }
        }
        self.surveysAndMessageTableData.sections[1] = self.listOfSurveys
        self.surveysAndMessagesTableView.reloadSections([1], with: UITableView.RowAnimation.fade)
    }

    // TODO: delete this function
    func refreshSurveys() {
        hakuba.removeAll();
        let section = Section() // create a new section

        hakuba
            .insert(section, atIndex: 0)
            .bump()

        var cnt = 0;
        if let activeSurveys = StudyManager.sharedInstance.currentStudy?.activeSurveys {
            let sortedSurveys = activeSurveys.sorted { (s1, s2) -> Bool in
                return s1.1.received > s2.1.received;
            }

            // because surveys do not have their state cleared when the done button is pressed, the buttons retain
            // the incomplete label and tapping on a finished always available survey results in loading to the "done" buttton on that survey.
            // (and creating a new file. see comments in StudyManager.swift for explination of this behavior.)
            
            for (_,active_survey) in sortedSurveys {
                if (!active_survey.isComplete || active_survey.survey?.alwaysAvailable ?? false) {
                    let cellmodel = SurveyCellModel(activeSurvey: active_survey) { [weak self] cell in
                        cell.isSelected = false;
                        if let strongSelf = self, let surveyCell = cell as? SurveyCell, let surveyId = surveyCell.cellmodel?.activeSurvey.survey?.surveyId {
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
            footerSeperator.isHidden = false
            surveysAndMessagesTableView.tableHeaderView = activeSurveyHeader;
            surveysAndMessagesTableView.isScrollEnabled = true
        } else {
            footerSeperator.isHidden = true
            surveysAndMessagesTableView.tableHeaderView = emptySurveyHeader;
            surveysAndMessagesTableView.isScrollEnabled = false
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
