import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Registrasi plugin Flutter
    GeneratedPluginRegistrant.register(with: self)

    // ✅ Set delegate agar notifikasi muncul walau app aktif
    UNUserNotificationCenter.current().delegate = self

    // ✅ Minta izin notifikasi
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        print("✅ Notifikasi diizinkan oleh pengguna")
      } else {
        print("❌ Notifikasi ditolak: \(String(describing: error))")
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ✅ Notifikasi tetap tampil di foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
