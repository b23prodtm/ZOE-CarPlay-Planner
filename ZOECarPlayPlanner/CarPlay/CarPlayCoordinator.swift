import CarPlay
import MapKit
import UIKit

// MARK: - CarPlayCoordinator

/// Coordinateur CarPlay centré sur les templates natifs du framework CarPlay.
/// Aucun écran secondaire UIKit / SwiftUI n'est utilisé pour l'affichage embarqué.
@available(iOS 14.0, *)
@MainActor
final class CarPlayCoordinator {
    private let interfaceController: CPInterfaceController

    private lazy var mapTemplate: CPMapTemplate = {
        let template = CPMapTemplate()
        template.mapButtons = [
            makeSettingsButton(),
            makeSendRouteButton()
        ]
        return template
    }()

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
    }

    // MARK: - Root Template

    func showRootTemplate() {
        interfaceController.setRootTemplate(mapTemplate, animated: true, completion: nil)
    }

    // MARK: - Map Buttons

    private func makeSettingsButton() -> CPMapButton {
        let button = CPMapButton { [weak self] _ in
            self?.showSettingsTemplate()
        }
        button.image = UIImage(systemName: "gearshape.fill")
        return button
    }

    private func makeSendRouteButton() -> CPMapButton {
        let button = CPMapButton { [weak self] _ in
            self?.sendTestRouteToAppleMaps()
        }
        button.image = UIImage(systemName: "location.north.fill")
        return button
    }

    // MARK: - Settings

    private func showSettingsTemplate() {
        let settingsItems = [
            CPListItem(text: "Niveau de batterie", detailText: "82 %"),
            CPListItem(text: "Filtre de bornes", detailText: "Rapides uniquement"),
            CPListItem(text: "Mode de paiement", detailText: "Carte bancaire")
        ]

        let section = CPListSection(items: settingsItems)
        let template = CPListTemplate(title: "Réglages", sections: [section])
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - Apple Maps

    private func sendTestRouteToAppleMaps() {
        let destinationCoordinate = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        destinationItem.name = "Station de recharge de test"
        destinationItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
