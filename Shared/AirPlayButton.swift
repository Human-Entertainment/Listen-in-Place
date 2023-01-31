import SwiftUI
import MediaPlayer
import AVKit

struct AirPlayButton: UIViewRepresentable {
    func updateUIView(_ routePickerView: UIView, context: Context) {
        let isDarkMode = context.environment.colorScheme == .dark
        routePickerView.tintColor = isDarkMode ? .white : .black
    }
    
    func makeUIView(context: Context) -> UIView {
        let routePickerView = AVRoutePickerView()
        
        let isDarkMode = context.environment.colorScheme == .dark
        routePickerView.tintColor = isDarkMode ? .white : .black
        routePickerView.backgroundColor = .clear
        
        // Indicate whether your app prefers video content.
        routePickerView.prioritizesVideoDevices = false

        return routePickerView
    }
}
