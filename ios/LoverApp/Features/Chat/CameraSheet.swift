import SwiftUI
import UIKit

// v1.0.4 — actual in-app camera capture. PhotoPickerSheet (PHPicker) only
// shows the photo library; the Composer's camera icon needs a different
// presentation that opens the camera. UIImagePickerController is still the
// only first-party way to get a viewfinder inside a SwiftUI sheet without
// rolling our own AVFoundation pipeline.
//
// On Simulator / devices without a camera, init returns nil — the parent
// should fall back to showing the photo picker instead.

struct CameraSheet: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        // .camera is only available when a hardware camera exists. Guard so
        // the constructor doesn't throw on Simulator.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraSheet
        init(_ parent: CameraSheet) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage,
               let data = img.jpegData(compressionQuality: 0.8) {
                parent.onPick(data)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
