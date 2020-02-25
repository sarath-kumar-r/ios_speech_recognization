//
//  ViewController.swift
//  Speech Recognization
//
//  Created by Sarath Kumar Rajendran on 24/02/20.
//  Copyright © 2020 Sarath Christiano. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    fileprivate let outLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.backgroundColor = .lightGray
        return label
    }()
    
    fileprivate let recordButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Record", for: .normal)
        button.backgroundColor = .lightGray
        return button
    }()
    
    private let contextualStrings = ["Create Record", "Where is Zoho Located?", "Tell me about Zoho projects/"]
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    private var currentWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        speechRecognizer.delegate = self
        // Asynchronously make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                    
                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }


    @objc fileprivate func stopRecog() {
        
        if self.audioEngine.isRunning {
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
        }
        self.recognitionTask?.cancel()
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        DispatchQueue.main.async {
            self.recordButton.isEnabled = true
            self.recordButton.setTitle("Start Recording", for: [])
        }
        print("Recognization stopped")
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        recognitionRequest.contextualStrings = contextualStrings
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
        
            if let result = result {
                // Update the text view with the results.
                self.outLabel.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                print("Recognized Text: \(result.bestTranscription.formattedString) ")
                
                
                // cancel the previous work item to prevent interuppting the recognization
                self.currentWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    if self.currentWorkItem?.isCancelled == false {
                        self.stopRecog()
                    }
                }
                
                //Idle time will be 1.5 seconds.
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5, execute: workItem)
                self.currentWorkItem = workItem
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.currentWorkItem?.cancel()
                self.stopRecog()
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Let the user know to start talking.
        outLabel.text = "(Go ahead, I'm listening)"
        
        
    }
    
    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    
    @objc func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Start Recording", for: [])
            outLabel.text = ""
        } else {
            do {
                recordButton.setTitle("Stop Recording", for: [])
                try startRecording()
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
}

fileprivate extension ViewController {
    
    func setUpView() {
        self.recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        self.view.addSubview(self.recordButton)
        self.view.addSubview(self.outLabel)
        addConstraints()
    }
    
    func addConstraints() {
        
        var constraints = NSLayoutConstraint.constraints(withVisualFormat: "H:[button(200)]", options: .alignAllCenterX, metrics: nil, views: ["button": self.recordButton])
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-100-[button(80)]", options: [], metrics: nil, views: ["button": self.recordButton])
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:[label(300)]", options: [], metrics: nil, views: ["label": self.outLabel])
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:[button]-100-[label(100)]", options: [], metrics: nil, views: ["label": self.outLabel, "button": recordButton])
        constraints.append(.init(item: recordButton, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
         constraints.append(.init(item: outLabel, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
        NSLayoutConstraint.activate(constraints)
    }
    
}
