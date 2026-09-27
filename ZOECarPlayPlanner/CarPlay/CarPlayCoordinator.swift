import CarPlay
import Foundation

// MARK: - CarPlayCoordinator

/// Coordinateur CarPlay — gère les templates et la navigation dans l'interface embarquée.
/// L'interface doit rester simple, lisible, et sûre pour la conduite.
@available(iOS 14.0, *)
@MainActor
final class CarPlayCoordinator {
    private let interfaceController: CPInterfaceController

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
    }

    // MARK: - Templates

    func showMainTemplate() {
        let template = buildMainListTemplate()
        interfaceController.setRootTemplate(template, animated: true, completion: nil)
    }

    // MARK: - Main List

    private func buildMainListTemplate() -> CPListTemplate {
        let items = [
            CPListItem(text: "ZOE", detailText: "82 % — 245 km"),
            CPListItem(text: "Destination", detailText: "Appuyez pour planifier"),
            CPListItem(text: "Plan de recharge", detailText: "Aucune recharge nécessaire")
        ]

        let section = CPListSection(items: items)
        let template = CPListTemplate(
            title: "ZOE CarPlay Planner",
            sections: [section]
        )
        return template
    }

    // MARK: - Route Result

    func showRoutePlan(plan: ChargingPlan, route: Route) {
        var items: [CPListItem] = []

        // Résumé du trajet
        items.append(CPListItem(
            text: "Trajet : \(route.displayDistance)",
            detailText: "Arrivée estimée : \(plan.displayArrivalSOC)"
        ))

        // Arrêts de recharge
        if plan.stops.isEmpty {
            items.append(CPListItem(text: "Recharge", detailText: "Aucune recharge nécessaire"))
        } else {
            for (index, stop) in plan.stops.enumerated() {
                let item = CPListItem(
                    text: "Recharge \(index + 1) — dans \(Int(stop.distanceFromOriginKm)) km",
                    detailText: "\(stop.displayArrivalSOC) → \(stop.displayTargetSOC) · \(stop.displayDuration)"
                )
                items.append(item)
            }
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Plan de recharge", sections: [section])
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - Information Template

    func showVehicleInfo(status: VehicleStatus) {
        let items: [CPInformationItem] = [
            CPInformationItem(title: "Batterie", detail: status.battery.displayPercent),
            CPInformationItem(title: "Autonomie", detail: "\(Int(status.battery.estimatedRangeKm)) km"),
            CPInformationItem(title: "État", detail: status.charging.displayName)
        ]
        let template = CPInformationTemplate(
            title: "ZOE",
            layout: .twoColumn,
            items: items,
            actions: []
        )
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }
}
