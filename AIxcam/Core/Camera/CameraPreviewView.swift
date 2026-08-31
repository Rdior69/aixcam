import AVFoundation
import HaishinKit
import SwiftUI

/// Camera preview powered by HaishinKit's Metal renderer.
/// Wraps MTHKViewRepresentable and overlays a tap-to-focus gesture.
struct CameraPreviewView: View {
    let previewSource: any MTHKViewRepresentable.PreviewSource
    var onTapToFocus: ((CGPoint, CGPoint) -> Void)?

    var body: some View {
        GeometryReader { geo in
            MTHKViewRepresentable(previewSource: previewSource, videoGravity: .resizeAspectFill)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let loc = value.location
                            guard geo.size.width > 0, geo.size.height > 0 else { return }
                            let devicePoint = CGPoint(
                                x: loc.x / geo.size.width,
                                y: loc.y / geo.size.height
                            )
                            onTapToFocus?(devicePoint, loc)
                        }
                )
        }
    }
}
