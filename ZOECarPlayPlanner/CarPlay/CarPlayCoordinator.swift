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
    private let itineraryDestinationProvider: () -> MKMapItem?

    private lazy var mapTemplate: CPMapTemplate = {
        let template = CPMapTemplate()
        var buttons = [
            makeSettingsButton(),
        ]
#if DEBUG
        buttons.append(makeSendRouteButton())
#else
        if itineraryDestinationProvider() != nil {
            buttons.append(makeSendRouteButton())
        }
#endif
        template.mapButtons = buttons
        return template
    }()

    init(
        interfaceController: CPInterfaceController,
        itineraryDestinationProvider: @escaping () -> MKMapItem? = { nil }
    ) {
        self.interfaceController = interfaceController
        self.itineraryDestinationProvider = itineraryDestinationProvider
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

    func sendRoute(to destinationItem: MKMapItem) {
        destinationItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func sendTestRouteToAppleMaps() {
        if let destinationItem = itineraryDestinationProvider() {
            sendRoute(to: destinationItem)
            return
        }

#if DEBUG
        sendRoute(to: makeDebugDestinationItem())
#endif
    }

#if DEBUG
    private func makeDebugDestinationItem() -> MKMapItem {
        let destinationCoordinate = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        destinationItem.name = "Station de recharge de test"
        return destinationItem
    }
#endif
}
