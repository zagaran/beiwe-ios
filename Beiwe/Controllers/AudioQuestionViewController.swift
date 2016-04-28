//
//  AudioQuestionViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/25/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import AVFoundation


class AudioQuestionViewController: UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate {

    enum AudioState {
        case Initial
        case Recording
        case Recorded
        case Playing
    }
    var activeSurvey: ActiveSurvey!
    var maxLen: Int = 60;
    var recordingSession: AVAudioSession!
    var recorder: AVAudioRecorder?
    var player: AVAudioPlayer?
    var filename: NSURL!
    var state: AudioState = .Initial
    var timer: NSTimer?
    var currentLength: Double = 0

    @IBOutlet weak var maxLengthLabel: UILabel!
    @IBOutlet weak var currentLengthLabel: UILabel!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var recordPlayButton: UIButton!
    @IBOutlet weak var reRecordButton: BWButton!
    @IBOutlet weak var saveButton: BWButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        promptLabel.text = activeSurvey.survey?.questions[0].prompt

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action:  #selector(cancelButton))

        reset()

        filename = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSUUID().UUIDString + ".mp4")

        recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] (allowed: Bool) -> Void in
                dispatch_async(dispatch_get_main_queue()) {
                    if !allowed {
                        self.fail()
                    }
                }
            }
        } catch {
            fail()
        }
        updateRecordButton()
        recorder = nil

        if let study = StudyManager.sharedInstance.currentStudy {
            // Just need to put any old answer in here...
            activeSurvey.bwAnswers["A"] = "A"
            Recline.shared.save(study).then {_ in
                print("Saved.");
                }.error {_ in
                    print("Error saving updated answers.");
            }
        }


    }

    func cleanupAndDismiss() {
        do {
            try NSFileManager.defaultManager().removeItemAtURL(filename)
        } catch { }
        recorder?.delegate = nil
        player?.delegate = nil
        recorder?.stop()
        player?.stop()
        player = nil;
        recorder = nil
        StudyManager.sharedInstance.surveysUpdatedEvent.emit();
        self.navigationController?.popViewControllerAnimated(true)
    }
    func cancelButton() {
        if (state != .Initial) {
            let alertController = UIAlertController(title: "Abandon recording?", message: "", preferredStyle: .ActionSheet)

            let leaveAction = UIAlertAction(title: "Abandon", style: .Destructive) { (action) in
                dispatch_async(dispatch_get_main_queue()) {
                    self.cleanupAndDismiss()
                }
            }
            alertController.addAction(leaveAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .Default) { (action) in
            }
            alertController.addAction(cancelAction)


            self.presentViewController(alertController, animated: true) {
                print("Ok");
            }

        } else {
            cleanupAndDismiss()
        }
    }

    func fail() {
        let alertController = UIAlertController(title: "Recording", message: "Unable to record.  You must allow access to the microphone to answer an audio question", preferredStyle: .Alert)

        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
            dispatch_async(dispatch_get_main_queue()) {
                self.cleanupAndDismiss()
            }
        }
        alertController.addAction(OKAction)

        self.presentViewController(alertController, animated: true) {
            print("Ok");
        }
    }

    func updateLengthLabel() {
        currentLengthLabel.text = "Length: \(currentLength) seconds"
    }

    func recordingTimer() {
        if let recorder = recorder {
            currentLength = round(recorder.currentTime * 10) / 10
            if (currentLength >= Double(maxLen)) {
                currentLength = Double(maxLen)
                if (recorder.recording) {
                    recorder.stop()
                }
            }

        }
        updateLengthLabel()
    }
    func startRecording() {
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVEncoderBitRateKey: 64 * 1024,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1 as NSNumber,
            AVEncoderAudioQualityKey: AVAudioQuality.High.rawValue
        ]

        do {
            // 5
            recorder = try AVAudioRecorder(URL: filename, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            state = .Recording
            updateLengthLabel()
            currentLengthLabel.hidden = false
            currentLength = 0;
            timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(recordingTimer), userInfo: nil, repeats: true)
        } catch  let error as NSError{
            print("Err: \(error)")
            fail()
        }
        updateRecordButton()
    }

    func stopRecording() {
        if let recorder = recorder {
            recorder.stop()
        }
    }

    func playRecording() {
        if let player = player {
            state = .Playing
            player.play()
            updateRecordButton()
        }
    }

    func stopPlaying() {
        if let player = player {
            state = .Recorded
            player.stop()
            player.currentTime = 0.0
            updateRecordButton()
        }
    }

    @IBAction func recordCancelPressed(sender: AnyObject) {
        switch(state) {
        case .Initial:
            startRecording()
        case .Recording:
            stopRecording()
        case .Recorded:
            playRecording()
        case .Playing:
            stopPlaying()
        }
    }
    @IBAction func saveButtonPressed(sender: AnyObject) {
        activeSurvey.isComplete = true;
        StudyManager.sharedInstance.updateActiveSurveys(true);
        cleanupAndDismiss()
    }

    func updateRecordButton() {
        var imageName: String;
        switch(state) {
        case .Initial:
            imageName = "record"
        case .Playing, .Recording:
            imageName = "stop"
        case .Recorded:
            imageName = "play"
        }

        let image = UIImage(named: imageName)
        recordPlayButton.setImage(image, forState: .Highlighted)
        recordPlayButton.setImage(image, forState: .Normal)
        recordPlayButton.setImage(image, forState: .Disabled)
    }
    func reset() {
        if let timer = timer {
            timer.invalidate();
        }
        player = nil
        recorder = nil
        state = .Initial
        saveButton.enabled = false
        reRecordButton.hidden = true
        maxLen = StudyManager.sharedInstance.currentStudy?.studySettings?.voiceRecordingMaxLengthSeconds ?? 60
        maxLen = 5
        maxLengthLabel.text = "Maximum length \(maxLen) seconds"
        currentLengthLabel.hidden = true
        updateRecordButton()
    }
    @IBAction func reRecordButtonPressed(sender: AnyObject) {
        recorder?.deleteRecording()
        reset()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
        if let timer = timer {
            timer.invalidate()
        }
        if (flag && currentLength > 0) {
            self.recorder = nil
            state = .Recorded
            saveButton.enabled = true
            reRecordButton.hidden = false
            do {
                player = try AVAudioPlayer(contentsOfURL: filename)
                player?.delegate = self
            } catch {
                reset()
            }
            updateRecordButton()
        } else {
            self.recorder?.deleteRecording()
            reset()
        }
    }

    func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder, error: NSError?) {
        self.recorder?.deleteRecording()
        reset()
    }

    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        if (state == .Playing) {
            state = .Recorded
            updateRecordButton()
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
