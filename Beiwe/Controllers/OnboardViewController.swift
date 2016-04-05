//
//  OnboardViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/3/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import ResearchKit;

class MyLogin: ORKLoginStepViewController {
    override func viewDidLoad() {
        super.viewDidLoad();


    }
}

class MyLoginStep : ORKLoginStep {

}

class OnboardViewController: ORKTaskViewController, ORKTaskViewControllerDelegate {

    var SurveyTask: ORKOrderedTask {

        var steps = [ORKStep]()

        let instructionStep = ORKInstructionStep(identifier: "IntroStep")
        instructionStep.title = "The Questions Three"
        instructionStep.text = "Who would cross the Bridge of Death must answer me these questions three, ere the other side they see."
        steps += [instructionStep]


        //TODO: add name question

        //TODO: add 'what is your quest' question

        //TODO: add color question step

        //TODO: add summary step

        return ORKOrderedTask(identifier: "SurveyTask", steps: steps)
    }


    override func viewDidLoad() {
        // Do any additional setup after loading the view.


        let consentDocument = ORKConsentDocument()
        consentDocument.title = "Example Consent"

        let consentSection = ORKConsentSection(type: .Overview);
        consentSection.summary = "If you wish to complete this study..."
        consentSection.content = "In this study you will be asked five (wait, no, three!) questions. You will also have your voice recorded for ten seconds."

        let consentSectionTypes: [ORKConsentSectionType] = [
            .Overview,
            .DataGathering,
            .Privacy,
            .DataUse,
            .TimeCommitment,
            .StudySurvey,
            .StudyTasks,
            .Withdrawing
        ]



        var consentSections: [ORKConsentSection] = consentSectionTypes.map { contentSectionType in
            let consentSection = ORKConsentSection(type: contentSectionType)
            consentSection.summary = "If you wish to complete this study..."
            consentSection.content = "In this study you will be asked five (wait, no, three!) questions. You will also have your voice recorded for ten seconds."
            return consentSection
        }

        consentDocument.addSignature(ORKConsentSignature(forPersonWithTitle: nil, dateFormatString: nil, identifier: "ConsentDocumentParticipantSignature"))
            
        consentDocument.sections = consentSections        //TODO: signature

        var ConsentTask: ORKOrderedTask;

        var steps = [ORKStep]()

        let loginStep = ORKLoginStep(identifier: "login", title: "Login", text: "Please login", loginViewControllerClass: MyLogin.self)


        steps += [loginStep];

        //let waitStep = ORKWaitStep(identifier: "wait");
        //steps += [waitStep];


        let instructionStep = ORKInstructionStep(identifier: "IntroStep")
        instructionStep.image = UIImage(named: "AppIcon60x60")
        instructionStep.title = "The Questions Three"
        instructionStep.text = "Who would cross the Bridge of Death must answer me these questions three, ere the other side they see."
        steps += [instructionStep]

        /*
        let formStep = ORKFormStep(identifier: "FormStep");
        formStep.title = "Register";
        formStep.text = "Register for your study";

        var formItems = [ORKFormItem]();
        formItems.append(ORKFormItem(sectionTitle: "data"));
        formItems.append(ORKFormItem(identifier: "userid", text: "UserID", answerFormat: ORKAnswerFormat.textAnswerFormatWithMaximumLength(10)));
        formItems.append(ORKFormItem(sectionTitle: "otherData"));
        formItems.append(ORKFormItem(identifier: "userid2", text: "moreText", answerFormat: ORKAnswerFormat.textAnswerFormat()));
        formItems.append(ORKFormItem(sectionTitle: "Third section"));

        formStep.formItems = formItems;

        steps += [formStep];
        */

        let visualConsentStep = ORKVisualConsentStep(identifier: "VisualConsentStep", document: consentDocument)
        steps += [visualConsentStep]

        let signature = consentDocument.signatures!.first!

        let reviewConsentStep = ORKConsentReviewStep(identifier: "ConsentReviewStep", signature: nil, inDocument: consentDocument)

        reviewConsentStep.text = "Review Consent!"
        reviewConsentStep.reasonForConsent = "Consent to join study"
        
        steps += [reviewConsentStep]

        self.showsProgressInNavigationBar = false;
        self.task = ORKOrderedTask(identifier: "ConsentTask", steps: steps)


        self.delegate = self;
        //self.task = SurveyTask;
        super.viewDidLoad()



    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)
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
    }

    func taskViewController(taskViewController: ORKTaskViewController, hasLearnMoreForStep step: ORKStep) -> Bool {
        return false;
    }

    func taskViewController(taskViewController: ORKTaskViewController, viewControllerForStep step: ORKStep) -> ORKStepViewController? {
        return nil;
    }

    func taskViewController(taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        print("Step will appear;");
        if (stepViewController.step?.identifier == "login") {
            stepViewController.cancelButtonItem = nil;
        }
        //stepViewController.continueButtonTitle = "Go!"
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
