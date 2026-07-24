import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioInterruptionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let messenger = engineBridge.applicationRegistrar.messenger() else { return }
    audioInterruptionChannel = FlutterMethodChannel(
      name: "clearhear/audio_interruption",
      binaryMessenger: messenger
    )
    audioInterruptionChannel?.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "startListening":
        self?.audioInterruptionChannel?.invokeMethod("onInterruptionListeningStarted", arguments: nil)
        result(true)
      case "stopListening":
        self?.audioInterruptionChannel?.invokeMethod("onInterruptionListeningStopped", arguments: nil)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func handleAudioInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    switch type {
    case .began:
      audioInterruptionChannel?.invokeMethod("onInterruptionBegan", arguments: nil)
    case .ended:
      let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
      let shouldResume = options.contains(.shouldResume)
      audioInterruptionChannel?.invokeMethod("onInterruptionEnded", arguments: ["shouldResume": shouldResume])
    @unknown default:
      break
    }
  }
}
