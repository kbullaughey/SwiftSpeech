# SwiftSpeech

<p>
<a href="https://developer.apple.com/swift"><img src="https://img.shields.io/badge/swift-5.2-fe562e"></a>
<a href="https://developer.apple.com/ios"><img src="https://img.shields.io/badge/iOS-13%2B-blue"></a>
<a href="https://github.com/apple/swift-package-manager"><img src="https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat"></a>
<a href="https://codebeat.co/projects/github-com-cay-zhang-swiftspeech-master"><img alt="codebeat badge" src="https://codebeat.co/badges/7151eef2-438b-4428-99cd-776961dcf8ab" /></a>
<a href="https://github.com/Cay-Zhang/SwiftSpeech/blob/master/LICENSE"><img src="http://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat"></a>
</p>

**Recognize your user's voice elegantly without having to figure out authorization and audio engines, with built-in SwiftUI, Combine, and multi-language support.**

SwiftSpeech is a wrapper framework for the Speech / SFSpeechRecognizer APIs for iOS and macOS with built-in SwiftUI, Combine publisher, and multi-language support.

- [Installation](#installation)
- [Usage](#usage)
- [SwiftUI Support](#swiftui)
- [License](#license)

## Installation
SwiftSpeech is available through Swift Package Manager. To use it, add a package dependency using URL:
```
https://github.com/Cay-Zhang/SwiftSpeech.git
```

## Usage
### SpeechRecognizer Class
#### Initializing
```swift
let speechRecognizer = SpeechRecognizer.new(id: id, locale: locale)
```
This adds a SpeechRecognizer instance to the shared instance pool that's managed by the framework.

⚠️ Warning: You should **never keep** a strong reference to a SpeechRecognizer instance. Instead, use its `id` property to keep track of it.
#### Start Recording
```swift
try speechRecognizer.startRecording()
```
This method will set up the audio stuff automatically for you and start recording the user's voice. You can now start receiving the recognition results by subscribing to one of the publishers the recognizer exposes.
#### Subscribing
Currently, a SpeechRecognizer instance has two publishers (you only need to subscribe to one of them): `stringPublisher` and `resultPublisher`.
`stringPublisher` directly emits the speech text recognized (By default, it will emit partial results, which means **you may receive multiple events**). You will receive a `.finished` completion event whenever the recognizer finishes processing the user's voice (i.e. `sfSpeechRecognitionResult.isFinal == true`), or you explicitly called the `cancel()` method on the recognizer. Afterward, the recognizer instance will be immediately disposed of.
You can subscribe to `stringPublisher` in the following way:
```swift
speechRecognizer.stringPublisher
    .sink { text in
        print("Speech Recognizer: \(text)")
    }
    .store(in: &speechRecognizer.cancelBag)
```
For `resultPublisher`, the subscribing process is similar, except that the type of the element it will emit is `Result<SFSpeechRecognitionResult, Error>` which encapsulates the entire partial result from the underlying `SFSpeechRecognizer` or the error it emits during recognition.
#### Retrieving
```swift
SpeechRecognizer.recognizer(withID: recordingRecognizerID)
```
This returns an optional SpeechRecognizer that you can then use to stop/cancel recording.
#### Stop Recording
```swift
SpeechRecognizer.recognizer(withID: recordingRecognizerID)?.stopRecording()
```
This stops recording the user's voice. Please keep in mind that unless you have explicitly call `stopRecording()`, the recognition process will not stop (i.e. you will never receive a completion event from the publishers) because the recognizer will keep recording & recognizing the user's voice.
#### Cancel
```swift
SpeechRecognizer.recognizer(withID: recordingChoiceID)?.cancel()
```
If you are not interested in the recognition result any more and want to stop recording now, you may immediately halt the recognition process and dipose of the recognizer by calling this method.

### SwiftUI Support
#### `isSpeechRecognitionAvailable` Environment Key
Add the modifier `.automaticEnvironmentForSpeechRecognition()` to your root view or the view you want to use speech recognition in. This will automatically request authorization when the view appears and set the `isSpeechRecognitionAvailable` environment for the view.

Then, use the following code whenever you want to know if speech recognition is available in your view (e.g. when writing a button for recording, you may want to disable it whenever speech recognition is unavailable).
```swift
@Environment(\.isSpeechRecognitionAvailable) var isSpeechRecognitionAvailable: Bool
```
## License
SwiftSpeech is available under the [MIT license](https://choosealicense.com/licenses/mit/).
