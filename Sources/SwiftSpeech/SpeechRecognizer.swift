//
//  SpeechRecognizer.swift
//
//
//  Created by Cay Zhang on 2019/10/19.
//

import SwiftUI
import Speech
import Combine

extension SwiftSpeech {
    @dynamicMemberLookup
    public struct Session : Identifiable {
        public let id: UUID
        
        public subscript<T>(dynamicMember keyPath: KeyPath<SpeechRecognizer, T>) -> T? {
            return SpeechRecognizer.recognizer(withID: id)?[keyPath: keyPath]
        }
        
        public init(id: UUID = UUID(), locale: Locale = .current) {
            self.id = id
            _ = SpeechRecognizer.new(id: id, locale: locale)
        }
        
        public func startRecording() throws {
            guard let recognizer = SpeechRecognizer.recognizer(withID: id) else { return }
            try recognizer.startRecording()
        }
        
        public func stopRecording() {
            guard let recognizer = SpeechRecognizer.recognizer(withID: id) else { return }
            recognizer.stopRecording()
        }
        
        public func cancel() {
            guard let recognizer = SpeechRecognizer.recognizer(withID: id) else { return }
            recognizer.cancel()
        }
        
    }
}



public class SpeechRecognizer {
    
    static var instances = [SpeechRecognizer]()
    
    public typealias ID = UUID
    
    private var id: SpeechRecognizer.ID
    
    private let speechRecognizer: SFSpeechRecognizer
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
 
    private let resultSubject: PassthroughSubject<Result<SFSpeechRecognitionResult, Error>, Never> = PassthroughSubject()
    
    /// A publisher that emits the SFSpeechRecognitionResult sent by the recognizer wrapped in a Swift Result.
    public var resultPublisher: AnyPublisher<Result<SFSpeechRecognitionResult, Error>, Never> {
        resultSubject
            .eraseToAnyPublisher()
    }
    
    /// A convenience publisher that emits the vocal string recognized.
    public var stringPublisher: AnyPublisher<String, Never> {
        resultSubject
            .compactMap { result -> String? in
                
                switch result {
                case let .success(result):
                    // if result.isFinal {
                    //     self.stopRecording()
                    // }
                    return result.bestTranscription.formattedString
                case let .failure(error):
                    // recording already stopped at this point
                    print(error)
                    
                    return nil
                }
                
            }
            .eraseToAnyPublisher()
    }
    
    public func startRecording() throws {
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app if it's on iOS/Mac Catalyst.
        #if canImport(UIKit)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        recognitionRequest.requiresOnDeviceRecognition = false
        
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                self.resultSubject.send(.success(result))
                if result.isFinal {
                    self.resultSubject.send(completion: .finished)
                    SpeechRecognizer.remove(id: self.id)
                }
            } else if let error = error {
                self.stopRecording()
                self.resultSubject.send(.failure(error))
                self.resultSubject.send(completion: .finished)
                SpeechRecognizer.remove(id: self.id)
            } else {
                fatalError("No result and no error")
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
    }
    
    public func stopRecording() {
        
        // Call this method explicitly to let the speech recognizer know that no more audio input is coming.
        self.recognitionRequest?.endAudio()
        
        // self.recognitionRequest = nil
        
        // For audio buffer–based recognition, recognition does not finish until this method is called, so be sure to call it when the audio source is exhausted.
        self.recognitionTask?.finish()
        
        // self.recognitionTask = nil
        
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    /// Call this method to immediately stop recording AND the recognition task (i.e. stop recognizing & receiving results).
    /// This method will call `stopRecording()` first and then send a completion (`.finished`) event to the publishers. Finally, it will cancel the recognition task and dispose of the SpeechRecognizer instance.
    public func cancel() {
        stopRecording()
        resultSubject.send(completion: .finished)
        recognitionTask?.cancel()
        SpeechRecognizer.remove(id: self.id)
    }
    
    // MARK: - Init
    fileprivate convenience init(id: ID = ID(), locale: Locale = .current) {
        let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        self.init(id: id, speechRecognizer: speechRecognizer)
    }
    
    fileprivate init(id: ID = ID(), speechRecognizer: SFSpeechRecognizer) {
        self.speechRecognizer = speechRecognizer
        self.speechRecognizer.defaultTaskHint = .search
        self.id = id
    }
    
    public static func new(id: ID = ID(), locale: Locale = .current) -> SpeechRecognizer {
        let recognizer = SpeechRecognizer(id: id, locale: locale)
        instances.append(recognizer)
        return recognizer
    }
    
    public static func recognizer(withID id: ID?) -> SpeechRecognizer? {
        return instances.first { $0.id == id }
    }
    
    @discardableResult
    public static func remove(id: ID?) -> SpeechRecognizer? {
        if let index = instances.firstIndex(where: { $0.id == id }) {
//            print("Removing speech recognizer: index \(index)")
            return instances.remove(at: index)
        } else {
//            print("Removing speech recognizer: no such id found")
            return nil
        }
    }
    
    deinit {
//        print("Speech Recognizer: Deinit")
        self.recognitionTask = nil
        self.recognitionRequest = nil
    }
    
}
