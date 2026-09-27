import CarPlay
import UIKit

// MARK: - CarPlaySceneDelegate
//
// IMPORTANT : L'entitlement CarPlay (com.apple.developer.carplay-navigation ou
// com.apple.developer.carplay-information) doit être activé dans votre compte
// développeur Apple avant d'utiliser CPTemplateApplicationScene en production.
// Ne pas inventer d'entitlement valide.
// Configurer uniquement lorsque disponible dans votre profil de provisioning.

@available(iOS 14.0, *)
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var coordinator: CarPlayCoordinator?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        coordinator = CarPlayCoordinator(interfaceController: interfaceController)
        coordinator?.showMainTemplate()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        coordinator = nil
    }
}
