//
//  OnboardingManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit

class TrackingSurveyPresenter : NSObject, ORKTaskViewControllerDelegate {

    var retainSelf: AnyObject?;
    var taskiewController: ORKTaskViewController!;
    var surveyId: String?;
    var activeSurvey: ActiveSurvey?;
    var survey: Survey?;
    var parent: UIViewController?;


    init(surveyId: String, activeSurvey: ActiveSurvey, survey: Survey) {
        super.init();
        self.surveyId = surveyId;
        self.activeSurvey = activeSurvey;
        self.survey = survey;
    }

    func present(parent: UIViewController) {
        guard  let survey = survey, activeSurvey = activeSurvey, surveyId = surveyId, stepOrder = activeSurvey.stepOrder where survey.questions.count > 0 else {
            return;
        }
        let numQuestions = survey.randomize ? min(survey.questions.count, survey.numberOfRandomQuestions ?? 999) : survey.questions.count;
        if (numQuestions == 0) {
            return;
        }
        self.parent = parent;
        var steps = [ORKStep]();

        for i in 0..<numQuestions {
            let question =  survey.questions[stepOrder[i]]
            if let questionType = question.questionType {
                var step: ORKStep?;
                //let questionStep = ORKQuestionStep(identifier: question.questionId);
                var format: ORKAnswerFormat?;
                switch(questionType) {
                case .Checkbox:
                    let questionStep = ORKQuestionStep(identifier: question.questionId);
                    step = questionStep;
                    questionStep.answerFormat = ORKTextAnswerFormat.choiceAnswerFormatWithStyle(.MultipleChoice, textChoices: question.selectionValues.enumerate().map { (index, el) in
                        return ORKTextChoice(text: el.text, value: index)
                        })
                case .FreeResponse:
                    let questionStep = ORKQuestionStep(identifier: question.questionId);
                    step = questionStep;
                    if let textFieldType = question.textFieldType {
                        switch(textFieldType) {
                        case .SingleLine:
                            let textFormat = ORKTextAnswerFormat.textAnswerFormat();
                            textFormat.multipleLines = false;
                            questionStep.answerFormat = textFormat;
                        case .Numeric:
                            questionStep.answerFormat = ORKNumericAnswerFormat.init(style: .Decimal, unit: nil, minimum: question.minValue, maximum: question.maxValue)
                        case .MultiLine:
                            let textFormat = ORKTextAnswerFormat.textAnswerFormat();
                            textFormat.multipleLines = true;
                            questionStep.answerFormat = textFormat;
                        }
                    }
                case .InformationText:
                    step = ORKInstructionStep(identifier: question.questionId);
                    break;
                case .RadioButton:
                    let questionStep = ORKQuestionStep(identifier: question.questionId);
                    step = questionStep;
                    questionStep.answerFormat = ORKTextAnswerFormat.choiceAnswerFormatWithStyle(.SingleChoice, textChoices: question.selectionValues.enumerate().map { (index, el) in
                        return ORKTextChoice(text: el.text, value: index)
                        })
                case .Slider:
                    if let minValue = question.minValue, maxValue = question.maxValue {
                        let questionStep = ORKQuestionStep(identifier: question.questionId);
                        step = questionStep;
                        questionStep.answerFormat = ORKScaleAnswerFormat.init(maximumValue: maxValue, minimumValue: minValue, defaultValue: minValue, step: 1);
                    }
                }
                if let step = step {
                    step.title = "Question"
                    step.text =  question.prompt
                    steps += [step];
                }
            }
        }

        let finishStep = ORKInstructionStep(identifier: "finished");
        finishStep.title = "Survey Completed";
        finishStep.text = StudyManager.sharedInstance.currentStudy?.studySettings?.submitSurveySuccessText;
        steps += [finishStep];


        let task = ORKOrderedTask(identifier: "SurveyTask", steps: steps)
        let surveyViewController = ORKTaskViewController(task: task, taskRunUUID: nil);
        //surveyViewController.showsProgressInNavigationBar = false;
        surveyViewController.delegate = self;

        self.retainSelf = self;
        parent.presentViewController(surveyViewController, animated: true, completion: nil)
        

    }

    func closeSurvey() {
        retainSelf = nil;
        parent?.dismissViewControllerAnimated(true, completion: nil);
    }

    /* ORK Delegates */
    func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)
        closeSurvey();
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
        switch(step.identifier) {
        default: return false;
        }
    }

    func taskViewController(taskViewController: ORKTaskViewController, viewControllerForStep step: ORKStep) -> ORKStepViewController? {
        return nil;
    }

    func taskViewController(taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        print("Step will appear;");
        if stepViewController.continueButtonTitle == "Get Started" {
            stepViewController.continueButtonTitle = "Continue";
        }
        if let identifier = stepViewController.step?.identifier {
            switch(identifier) {
            case "finished":
                activeSurvey?.isComplete = true;
                StudyManager.sharedInstance.updateActiveSurveys(true);
                stepViewController.cancelButtonItem = nil;
                stepViewController.backButtonItem = nil;
            default: break
            }
        }
        /*
        if (stepViewController.step?.identifier == "login") {
            stepViewController.cancelButtonItem = nil;
        }
        */
 
        //stepViewController.continueButtonTitle = "Go!"
    }
}