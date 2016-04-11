//
//  TaskListViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/6/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import Eureka
import EmitterKit

class TaskListViewController: FormViewController {

    let surveySelected = Event<String>();
    let pendingSection =  Section("Pending Study Tasks");
    let dateFormatter = NSDateFormatter();
    var listeners: [Listener] = [];

    override func viewDidLoad() {
        super.viewDidLoad()

        dateFormatter.dateFormat = "MMM d h:mm a";

        form +++ pendingSection

        loadSurveys();

        listeners += StudyManager.sharedInstance.surveysUpdatedEvent.on {
            self.loadSurveys();
        }

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func loadSurveys() {
        pendingSection.removeAll();

        if let activeSurveys = StudyManager.sharedInstance.currentStudy?.activeSurveys {
            let sortedSurveys = activeSurveys.sort { (s1, s2) -> Bool in
                return s1.1.received > s2.1.received;
            }

            for (id,survey) in sortedSurveys {
                let surveyType = SurveyTypes(rawValue: survey.survey!.surveyType);
                if let surveyType = surveyType where !survey.isComplete {
                    var title: String;
                    switch(surveyType) {
                    case .TrackingSurvey:
                        title = "Survey"
                    case .AudioSurvey:
                        title = "Audio Quest."
                    }
                    title = title + " recvd. " + dateFormatter.stringFromDate(NSDate(timeIntervalSince1970: survey.received))
                    pendingSection    <<< ButtonRow(id) {
                        $0.title = title
                        }
                        .onCellSelection {
                            [unowned self] cell, row in
                            print("Selected")
                            self.surveySelected.emit("survey")
                    }
                }
            }
        }

    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
