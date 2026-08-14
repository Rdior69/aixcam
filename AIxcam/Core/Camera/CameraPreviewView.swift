import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapToFocus: ((CGPoint, CGPoint) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapToFocus: onTapToFocus)
    }

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        context.coordinator.previewView = view

        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
        context.coordinator.previewView = uiView
        context.coordinator.onTapToFocus = onTapToFocus
    }

    final class Coordinator: NSObject {
        weak var previewView: CameraPreviewContainerView?
        var onTapToFocus: ((CGPoint, CGPoint) -> Void)?

        init(onTapToFocus: ((CGPoint, CGPoint) -> Void)?) {
            self.onTapToFocus = onTapToFocus
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let previewView else { return }
            let layerPoint = gesture.location(in: previewView)
            let devicePoint = previewView.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            onTapToFocus?(devicePoint, layerPoint)
        }
    }
}

final class CameraPreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = self.layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        return layer
    }
}
