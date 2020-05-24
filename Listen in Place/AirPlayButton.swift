import SwiftUI
import MediaPlayer

struct AirPlayButton: UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<AirPlayButton>) -> UIViewController {
        return AirPLayViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<AirPlayButton>) {

    }
}

class AirPLayViewController: UIViewController {
    let button = UIButton()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let isDarkMode = self.traitCollection.userInterfaceStyle == .dark
        
        
        let boldConfig = UIImage.SymbolConfiguration(scale: .large)
        let boldSearch = UIImage(systemName: "airplayaudio",
                                 withConfiguration: boldConfig)

        button.setImage(boldSearch, for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.tintColor = isDarkMode ? .white : .black

        button.addTarget(self,
                         action: #selector(self.showAirPlayMenu(_:)),
                         for: .touchUpInside)
        
        self.view.addSubview(button)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let isDarkMode = self.traitCollection.userInterfaceStyle == .dark
        button.tintColor = isDarkMode ? .white : .black
    }
    
    @objc func showAirPlayMenu(_ sender: UIButton){ // copied from https://stackoverflow.com/a/44909445/7974174
        let rect = CGRect(x: 0, y: 0, width: 0, height: 0)
        let airplayVolume = MPVolumeView(frame: rect)
        airplayVolume.showsVolumeSlider = false
        self.view.addSubview(airplayVolume)
        for view: UIView in airplayVolume.subviews {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
        airplayVolume.removeFromSuperview()
    }
}
