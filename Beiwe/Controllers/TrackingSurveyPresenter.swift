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
    static let timingsHeaders = ["timestamp","question id", "question type", "question text", "question answer options","answer", "event"];
    static let surveyDataType = "surveyAnswers"
    static let timingDataType = "surveyTimings"
    var retainSelf: AnyObject?;
    var surveyId: String?;
    var activeSurvey: ActiveSurvey?;
    var survey: Survey?;
    var parent: UIViewController?;
    var surveyViewController: BWORKTaskViewController?;
    var isComplete = false;
    var questionIdToQuestion: [String: GenericSurveyQuestion] = [:];
    var timingsStore: DataStorage?;
    var task: ORKTask?;
    var valueChangeHandler: Debouncer<String>?

    var currentQuestion: GenericSurveyQuestion? = nil;

    init(surveyId: String, activeSurvey: ActiveSurvey, survey: Survey) {
        super.init();
        self.surveyId = surveyId;
        self.activeSurvey = activeSurvey;
        self.survey = survey;

        let timingsName = TrackingSurveyPresenter.timingDataType + "_" + surveyId;
        timingsStore = DataStorageManager.sharedInstance.createStore(timingsName, headers: TrackingSurveyPresenter.timingsHeaders)

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
                    questionIdToQuestion[question.questionId] = question;
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


        task = ORKOrderedTask(identifier: "SurveyTask", steps: steps)
    }

    func present(parent: UIViewController) {
        //surveyViewController.showsProgressInNavigationBar = false;

        if let activeSurvey = activeSurvey, restorationData = activeSurvey.rkAnswers {
            surveyViewController = BWORKTaskViewController(task: task, restorationData: restorationData, delegate: self);
        } else {
            surveyViewController = BWORKTaskViewController(task: task, taskRunUUID: nil);
            surveyViewController!.delegate = self;
        }


        self.parent = parent;
        self.retainSelf = self;
        surveyViewController!.displayDiscard = false;
        parent.presentViewController(surveyViewController!, animated: true, completion: nil)
        

    }

    func arrayAnswer(array: [String]) -> String {
        return "[" + array.joinWithSeparator(";") + "]"
    }

    func storeAnswer(identifier: String, result: ORKTaskResult) {
        guard let question = questionIdToQuestion[identifier], stepResult = result.stepResultForStepIdentifier(identifier) else {
            return;
        }

        var answersString = "";

        if let questionType = question.questionType {
            switch(questionType) {
            case .Checkbox, .RadioButton:
                if let results = stepResult.results {
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
                if let results = stepResult.results {
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
                if let results = stepResult.results {
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
        activeSurvey?.bwAnswers[identifier] = answersString;
    }

    func questionResponse(question: GenericSurveyQuestion) -> (String, String, String) {
        var typeString = "";
        var optionsString = "";
        var answersString = "";

        if let questionType = question.questionType {
            typeString = questionType.rawValue
            if let answer = activeSurvey?.bwAnswers[question.questionId] {
                answersString = answer;
            } else {
                answersString = "not_presented";
            }
            switch(questionType) {
            case .Checkbox, .RadioButton:
                optionsString = arrayAnswer(question.selectionValues.map { return $0.text });
            case .FreeResponse:
                optionsString = "Text-field input type = " + (question.textFieldType?.rawValue ?? "");
            case .InformationText:
                answersString = "";
                break;
            case .Slider:
                if let minValue = question.minValue, maxValue = question.maxValue {
                    optionsString = "min = " + String(minValue) + "; max = " + String(maxValue)
                }
            }
        }
        return (typeString, optionsString, answersString);
    }

    func finalizeSurveyAnswers() -> Bool {
        guard let activeSurvey = activeSurvey, survey = activeSurvey.survey, surveyId = surveyId, patientId = StudyManager.sharedInstance.currentStudy?.patientId, publicKey = StudyManager.sharedInstance.currentStudy?.studySettings?.clientPublicKey else {
            return false;
        }
        guard  let stepOrder = activeSurvey.stepOrder where survey.questions.count > 0 else {
            return false;
        }
        let name = TrackingSurveyPresenter.surveyDataType + "_" + surveyId;
        let dataFile = DataStorage(type: name, headers: TrackingSurveyPresenter.headers, patientId: patientId, publicKey: publicKey);
        dataFile.sanitize = true;

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

    func addTimingsEvent(event: String, question: GenericSurveyQuestion?, forcedValue: String? = nil) {
        var data: [String] = [ String(Int64(NSDate().timeIntervalSince1970 * 1000)) ]
        if let question = question {
            data.append(question.questionId);
            let (questionType, optionsString, answersString) = questionResponse(question);
            data.append(questionType);
            data.append(question.prompt ?? "");
            data.append(optionsString);
            data.append(forcedValue != nil ? forcedValue! : answersString);
        } else {
            data.append("");
            data.append("");
            data.append("");
            data.append("");
            data.append(forcedValue != nil ? forcedValue! : "");
        }
        data.append(event);
        print("TimingsEvent: \(data.joinWithSeparator(","))")
        timingsStore?.store(data);

    }

    func possiblyAddUnpresent() {
        valueChangeHandler?.flush();
        valueChangeHandler = nil;
        if let currentQuestion = currentQuestion {
            addTimingsEvent("unpresent", question: currentQuestion);
            self.currentQuestion = nil;
        }
    }



    func closeSurvey() {
        retainSelf = nil;
        parent?.dismissViewControllerAnimated(true, completion: nil);
    }

    /* ORK Delegates */
    func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
        possiblyAddUnpresent();
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

        //print("didChangeStepId: \(taskViewController.currentStepViewController!.step!.identifier)")
        if let identifier = taskViewController.currentStepViewController!.step?.identifier {
            storeAnswer(identifier, result: result)
            let currentValue = activeSurvey!.bwAnswers[identifier];
            valueChangeHandler?.call(currentValue);
        }
        return;
    }

    func taskViewController(taskViewController: ORKTaskViewController, shouldPresentStep step: ORKStep) -> Bool {
        possiblyAddUnpresent();
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
        currentQuestion = nil;

        if stepViewController.continueButtonTitle == "Get Started" {
            stepViewController.continueButtonTitle = "Continue";
        }
        if let identifier = stepViewController.step?.identifier {
            switch(identifier) {
            case "finished":
                //createSurveyAnswers();
                addTimingsEvent("submitted", question: nil)
                StudyManager.sharedInstance.submitSurvey(activeSurvey!, surveyPresenter: self);
                activeSurvey?.rkAnswers = taskViewController.restorationData;
                activeSurvey?.isComplete = true;
                isComplete = true;
                StudyManager.sharedInstance.updateActiveSurveys(true);
                stepViewController.cancelButtonItem = nil;
                stepViewController.backButtonItem = nil;
            case "confirm":
                stepViewController.continueButtonTitle = "Confirm";
            default:
                if let question = questionIdToQuestion[identifier] {
                    currentQuestion = question;
                    if (activeSurvey?.bwAnswers[identifier] == nil) {
                        activeSurvey?.bwAnswers[identifier] = "";
                    }
                    var currentValue = activeSurvey!.bwAnswers[identifier];
                    addTimingsEvent("present", question: question);
                    var delay = 0.0;
                    if (question.questionType == SurveyQuestionType.Slider) {
                        delay = 0.25;
                    }
                    valueChangeHandler = Debouncer<String>(delay: delay) { [weak self] val in
                        if let strongSelf = self {
                            if (currentValue != val) {
                                currentValue = val;
                                strongSelf.addTimingsEvent("changed", question: question, forcedValue: val);
                            }
                        }
                    }
                }
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