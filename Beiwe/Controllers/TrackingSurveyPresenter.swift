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

    static let headers = ["question id", "question type", "question text", "question answer options","answer"];
    static let dataType = "surveyAnswers"
    var retainSelf: AnyObject?;
    var surveyId: String?;
    var activeSurvey: ActiveSurvey?;
    var survey: Survey?;
    var parent: UIViewController?;
    var surveyViewController: BWORKTaskViewController?;
    var isComplete = false;



    init(surveyId: String, activeSurvey: ActiveSurvey, survey: Survey) {
        super.init();
        self.surveyId = surveyId;
        self.activeSurvey = activeSurvey;
        self.survey = survey;

        guard  let stepOrder = activeSurvey.stepOrder where survey.questions.count > 0 else {
            return;
        }
        let numQuestions = survey.randomize ? min(survey.questions.count, survey.numberOfRandomQuestions ?? 999) : survey.questions.count;
        if (numQuestions == 0) {
            return;
        }
        var steps = [ORKStep]();

        for i in 0..<numQuestions {
            let question =  survey.questions[stepOrder[i]]
            if let questionType = question.questionType {
                var step: ORKStep?;
                //let questionStep = ORKQuestionStep(identifier: question.questionId);
                switch(questionType) {
                case .Checkbox, .RadioButton:
                    let questionStep = ORKQuestionStep(identifier: question.questionId);
                    step = questionStep;
                    questionStep.answerFormat = ORKTextAnswerFormat.choiceAnswerFormatWithStyle(questionType == .RadioButton ? .SingleChoice : .MultipleChoice, textChoices: question.selectionValues.enumerate().map { (index, el) in
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
                case .Slider:
                    if let minValue = question.minValue, maxValue = question.maxValue {
                        let questionStep = ORKQuestionStep(identifier: question.questionId);
                        step = questionStep;
                        /*
                        questionStep.answerFormat = ORKScaleAnswerFormat.init(maximumValue: maxValue, minimumValue: minValue, defaultValue: minValue, step: 1);
                        */
                        questionStep.answerFormat = BWORKScaleAnswerFormat.init(maximumValue: maxValue, minimumValue: minValue, defaultValue: minValue, step: 1);
                    }
                }
                if let step = step {
                    step.title = "Question"
                    step.text =  question.prompt
                    steps += [step];
                }
            }
        }

        let submitStep = ORKInstructionStep(identifier: "confirm");
        submitStep.title = "Confirm Submission";
        submitStep.text = "Thanks! You have finished answering all of the survey questions.  Pressing the submit button will now schedule your answers to be delivered";
        steps += [submitStep];

        let finishStep = ORKInstructionStep(identifier: "finished");
        finishStep.title = "Survey Completed";
        finishStep.text = StudyManager.sharedInstance.currentStudy?.studySettings?.submitSurveySuccessText;
        steps += [finishStep];


        let task = ORKOrderedTask(identifier: "SurveyTask", steps: steps)
        if let restorationData = activeSurvey.rkAnswers {
            surveyViewController = BWORKTaskViewController(task: task, restorationData: restorationData, delegate: nil);
            /*
            if let results = surveyViewController!.result.results {
                for r in results {
                    print("R: \(r)");

                }
            }
            */
        } else {
            surveyViewController = BWORKTaskViewController(task: task, taskRunUUID: nil);
        }

    }

    func present(parent: UIViewController) {
        //surveyViewController.showsProgressInNavigationBar = false;
        guard let surveyViewController = surveyViewController else {
            return;
        }

        self.parent = parent;
        self.retainSelf = self;
        surveyViewController.delegate = self;
        surveyViewController.displayDiscard = false;
        parent.presentViewController(surveyViewController, animated: true, completion: nil)
        

    }

    func arrayAnswer(array: [String]) -> String {
        return "[" + array.joinWithSeparator(";") + "]"
    }

    func questionResponse(question: GenericSurveyQuestion) -> (String, String, String) {
        var typeString = "";
        var optionsString = "";
        var answersString = "";

        if let questionType = question.questionType {
            typeString = questionType.rawValue
            let stepResults = surveyViewController?.result.stepResultForStepIdentifier(question.questionId);
            if (stepResults == nil) {
                answersString = "not_presented";
            }
            switch(questionType) {
            case .Checkbox, .RadioButton:
                optionsString = arrayAnswer(question.selectionValues.map { return $0.text });
                if let results = stepResults?.results {
                    if let choiceResults = results as? [ORKChoiceQuestionResult] {
                        if (choiceResults.count > 0) {
                            if let choiceAnswers = choiceResults[0].choiceAnswers {
                                var arr: [String] = [ ];
                                for a in choiceAnswers {
                                    if let num: NSNumber = a as? NSNumber {
                                        let numValue: Int = num.integerValue;
                                        if (numValue >= 0 && numValue < question.selectionValues.count) {
                                            arr.append(question.selectionValues[numValue].text);
                                        } else {
                                            arr.append("");
                                        }
                                    } else {
                                        arr.append("");
                                    }
                                }
                                if (questionType == .Checkbox) {
                                    answersString = arrayAnswer(arr);
                                } else {
                                    answersString = arr.count > 0 ? arr[0] : "";
                                }
                            }
                        }
                    }
                }
            case .FreeResponse:
                optionsString = "Text-field input type = " + (question.textFieldType?.rawValue ?? "");
                if let results = stepResults?.results {
                    if let freeResponses = results as? [ORKQuestionResult] {
                        if (freeResponses.count > 0) {
                            if let answer = freeResponses[0].answer {
                                answersString = String(answer);
                            }
                        }
                    }
                }
            case .InformationText:
                break;
            case .Slider:
                if let minValue = question.minValue, maxValue = question.maxValue {
                    optionsString = "min = " + String(minValue) + "; max = " + String(maxValue)
                }
                if let results = stepResults?.results {
                    if let sliderResults = results as? [ORKScaleQuestionResult] {
                        if (sliderResults.count > 0) {
                            if let answer = sliderResults[0].scaleAnswer {
                                answersString = String(answer);
                            }
                        }
                    }
                }
            }
        }
        return (typeString, optionsString, answersString);
    }

    func createSurveyAnswers() -> Bool {
        guard let activeSurvey = activeSurvey, survey = activeSurvey.survey, surveyId = surveyId, patientId = StudyManager.sharedInstance.currentStudy?.patientId, publicKey = StudyManager.sharedInstance.currentStudy?.studySettings?.clientPublicKey else {
            return false;
        }
        guard  let stepOrder = activeSurvey.stepOrder where survey.questions.count > 0 else {
            return false;
        }
        let name = TrackingSurveyPresenter.dataType + "_" + surveyId;
        let dataFile = DataStorage(type: name, headers: TrackingSurveyPresenter.headers, patientId: patientId, publicKey: publicKey);

        let numQuestions = survey.randomize ? min(survey.questions.count, survey.numberOfRandomQuestions ?? 999) : survey.questions.count;
        if (numQuestions == 0) {
            return false;
        }

        //     static let headers = ["question id", "question type", "question text", "question answer options","answer"];

        for i in 0..<numQuestions {
            let question =  survey.questions[stepOrder[i]];
            var data = [ question.questionId ];
            let (questionType, optionsString, answersString) = questionResponse(question);
            data.append(questionType);
            data.append(question.prompt ?? "");
            data.append(optionsString);
            data.append(answersString);
            dataFile.store(data);
        }
        dataFile.closeAndReset();
        return !dataFile.hasError;
        
    }

    func closeSurvey() {
        retainSelf = nil;
        parent?.dismissViewControllerAnimated(true, completion: nil);
    }

    /* ORK Delegates */
    func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)
        if (!isComplete) {
            activeSurvey?.rkAnswers = taskViewController.restorationData;
            if let study = StudyManager.sharedInstance.currentStudy {
                Recline.shared.save(study).then {_ in
                    print("Saved.");
                    }.error {_ in
                        print("Error saving updated answers.");
                }
            }
        }
        closeSurvey();
        print("Finished.");
    }

    func taskViewController(taskViewController: ORKTaskViewController, didChangeResult result: ORKTaskResult) {

        print("didChangeStepId: \(taskViewController.currentStepViewController!.step!.identifier)")
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

    func taskViewControllerSupportsSaveAndRestore(taskViewController: ORKTaskViewController) -> Bool {
        return false;
    }

    func taskViewController(taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        print("stepWillAppear: \(taskViewController.currentStepViewController!.step!.identifier)")
        if stepViewController.continueButtonTitle == "Get Started" {
            stepViewController.continueButtonTitle = "Continue";
        }
        if let identifier = stepViewController.step?.identifier {
            switch(identifier) {
            case "finished":
                createSurveyAnswers();
                activeSurvey?.rkAnswers = taskViewController.restorationData;
                activeSurvey?.isComplete = true;
                isComplete = true;
                StudyManager.sharedInstance.updateActiveSurveys(true);
                stepViewController.cancelButtonItem = nil;
                stepViewController.backButtonItem = nil;
            case "confirm":
                stepViewController.continueButtonTitle = "Confirm";
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