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

    override func viewDidLoad() {
        super.viewDidLoad()

        form +++ Section("Pending Study Tasks")
            <<< ButtonRow() {
                $0.title = "Survey recvd. Apr, 6 4:33pm"
                }
                .onCellSelection {
                    [unowned self] cell, row in
                    print("Selected")
                    self.surveySelected.emit("survey")
            }
            <<< ButtonRow() {
                $0.title = "Survey recvd. Apr, 2 4:33pm"
                }.onCellSelection { [unowned self] cell, row in
                    self.surveySelected.emit("survey")

        }

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
