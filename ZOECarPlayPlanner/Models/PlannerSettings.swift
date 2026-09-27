import Foundation
import UIKit

// MARK: - PlannerSettings

/// Réglages utilisateur persistants pour le planificateur.
final class PlannerSettings: ObservableObject, Codable {
    @Published var consumptionWhPerKm: Double
    @Published var minBatteryAtArrivalPercent: Double
    @Published var maxBatteryAfterChargePercent: Double
    @Published var safetyMarginPercent: Double
    @Published var preferredChargingPowerKW: Double
    @Published var useSimulationMode: Bool
    @Published var simulatedSOCPercent: Double
    @Published var vehicle: Vehicle
    @Published var routePreferences: RoutePreferences
    @Published var selectedChargingNetworks: [ChargingNetwork]
    @Published var selectedConnectorTypes: [ConnectorType]
    @Published var preferHighwayStations: Bool
    @Published var manualSOCSliderLayout: ManualSOCSliderLayout
    @Published var preferredNavigationApp: PreferredNavigationApp
    @Published var dashboardWallpaperFilename: String?

    init(
        consumptionWhPerKm: Double = 170,
        minBatteryAtArrivalPercent: Double = 15,
        maxBatteryAfterChargePercent: Double = 80,
        safetyMarginPercent: Double = 10,
        preferredChargingPowerKW: Double = 22,
        useSimulationMode: Bool = true,
        simulatedSOCPercent: Double = 82,
        vehicle: Vehicle = .defaultZOE,
        routePreferences: RoutePreferences = .init(),
        selectedChargingNetworks: [ChargingNetwork] = ChargingNetwork.allCases,
        selectedConnectorTypes: [ConnectorType] = [.type2AC, .ccs],
        preferHighwayStations: Bool = true,
        manualSOCSliderLayout: ManualSOCSliderLayout = .centered,
        preferredNavigationApp: PreferredNavigationApp = .appleMaps,
        dashboardWallpaperFilename: String? = nil
    ) {
        self.consumptionWhPerKm = consumptionWhPerKm
        self.minBatteryAtArrivalPercent = minBatteryAtArrivalPercent
        self.maxBatteryAfterChargePercent = maxBatteryAfterChargePercent
        self.safetyMarginPercent = safetyMarginPercent
        self.preferredChargingPowerKW = preferredChargingPowerKW
        self.useSimulationMode = useSimulationMode
        self.simulatedSOCPercent = simulatedSOCPercent
        self.vehicle = vehicle
        self.routePreferences = routePreferences
        self.selectedChargingNetworks = selectedChargingNetworks
        self.selectedConnectorTypes = selectedConnectorTypes
        self.preferHighwayStations = preferHighwayStations
        self.manualSOCSliderLayout = manualSOCSliderLayout
        self.preferredNavigationApp = preferredNavigationApp
        self.dashboardWallpaperFilename = dashboardWallpaperFilename
    }

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case consumptionWhPerKm, minBatteryAtArrivalPercent, maxBatteryAfterChargePercent
        case safetyMarginPercent, preferredChargingPowerKW, useSimulationMode
        case simulatedSOCPercent, vehicle, routePreferences, selectedChargingNetworks
        case selectedConnectorTypes, preferHighwayStations, manualSOCSliderLayout, preferredNavigationApp, dashboardWallpaperFilename
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        consumptionWhPerKm = try c.decodeIfPresent(Double.self, forKey: .consumptionWhPerKm) ?? 170
        minBatteryAtArrivalPercent = try c.decodeIfPresent(Double.self, forKey: .minBatteryAtArrivalPercent) ?? 15
        maxBatteryAfterChargePercent = try c.decodeIfPresent(Double.self, forKey: .maxBatteryAfterChargePercent) ?? 80
        safetyMarginPercent = try c.decodeIfPresent(Double.self, forKey: .safetyMarginPercent) ?? 10
        preferredChargingPowerKW = try c.decodeIfPresent(Double.self, forKey: .preferredChargingPowerKW) ?? 22
        useSimulationMode = try c.decodeIfPresent(Bool.self, forKey: .useSimulationMode) ?? true
        simulatedSOCPercent = try c.decodeIfPresent(Double.self, forKey: .simulatedSOCPercent) ?? 82
        vehicle = try c.decodeIfPresent(Vehicle.self, forKey: .vehicle) ?? .defaultZOE
        routePreferences = try c.decodeIfPresent(RoutePreferences.self, forKey: .routePreferences) ?? .init()
        selectedChargingNetworks = try c.decodeIfPresent([ChargingNetwork].self, forKey: .selectedChargingNetworks) ?? ChargingNetwork.allCases
        selectedConnectorTypes = try c.decodeIfPresent([ConnectorType].self, forKey: .selectedConnectorTypes) ?? [.type2AC, .ccs]
        preferHighwayStations = try c.decodeIfPresent(Bool.self, forKey: .preferHighwayStations) ?? true
        manualSOCSliderLayout = try c.decodeIfPresent(ManualSOCSliderLayout.self, forKey: .manualSOCSliderLayout) ?? .centered
        preferredNavigationApp = try c.decodeIfPresent(PreferredNavigationApp.self, forKey: .preferredNavigationApp) ?? .appleMaps
        dashboardWallpaperFilename = try c.decodeIfPresent(String.self, forKey: .dashboardWallpaperFilename)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(consumptionWhPerKm, forKey: .consumptionWhPerKm)
        try c.encode(minBatteryAtArrivalPercent, forKey: .minBatteryAtArrivalPercent)
        try c.encode(maxBatteryAfterChargePercent, forKey: .maxBatteryAfterChargePercent)
        try c.encode(safetyMarginPercent, forKey: .safetyMarginPercent)
        try c.encode(preferredChargingPowerKW, forKey: .preferredChargingPowerKW)
        try c.encode(useSimulationMode, forKey: .useSimulationMode)
        try c.encode(simulatedSOCPercent, forKey: .simulatedSOCPercent)
        try c.encode(vehicle, forKey: .vehicle)
        try c.encode(routePreferences, forKey: .routePreferences)
        try c.encode(selectedChargingNetworks, forKey: .selectedChargingNetworks)
        try c.encode(selectedConnectorTypes, forKey: .selectedConnectorTypes)
        try c.encode(preferHighwayStations, forKey: .preferHighwayStations)
        try c.encode(manualSOCSliderLayout, forKey: .manualSOCSliderLayout)
        try c.encode(preferredNavigationApp, forKey: .preferredNavigationApp)
        try c.encodeIfPresent(dashboardWallpaperFilename, forKey: .dashboardWallpaperFilename)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "PlannerSettings")
        }
    }

    func setChargingNetwork(_ network: ChargingNetwork, isEnabled: Bool) {
        updateSelection(&selectedChargingNetworks, value: network, isEnabled: isEnabled)
    }

    func setConnectorType(_ connector: ConnectorType, isEnabled: Bool) {
        updateSelection(&selectedConnectorTypes, value: connector, isEnabled: isEnabled)
    }

    static func load() -> PlannerSettings {
        guard let data = UserDefaults.standard.data(forKey: "PlannerSettings"),
              let settings = try? JSONDecoder().decode(PlannerSettings.self, from: data)
        else { return PlannerSettings() }
        return settings
    }

    private func updateSelection<T: Equatable>(_ collection: inout [T], value: T, isEnabled: Bool) {
        if isEnabled {
            if !collection.contains(value) {
                collection.append(value)
            }
        } else if collection.count > 1 {
            collection.removeAll { $0 == value }
        }
    }
}

enum PreferredNavigationApp: String, Codable, CaseIterable, Sendable {
    case appleMaps
    case googleMaps
    case waze
    case roole

    var displayName: String {
        switch self {
        case .appleMaps: return "Apple Plans"
        case .googleMaps: return "Google Maps"
        case .waze: return "Waze"
        case .roole: return "Roole"
        }
    }
}

enum ManualSOCSliderLayout: String, Codable, CaseIterable, Sendable {
    case centered
    case vertical

    var displayName: String {
        switch self {
        case .centered:
            return "Horizontal (centre)"
        case .vertical:
            return "Vertical"
        }
    }
}

enum DashboardWallpaperStore {
    nonisolated(unsafe) private static let fileManager = FileManager.default
    private static let directoryName = "DashboardWallpaper"

    static func saveImageData(_ data: Data) throws -> String {
        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let preparedImage = image.resizedForDashboard()
        guard let jpegData = preparedImage.jpegData(compressionQuality: 0.82) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let directory = try makeDirectoryIfNeeded()
        let filename = "wallpaper.jpg"
        let url = directory.appendingPathComponent(filename)
        try jpegData.write(to: url, options: [.atomic])
        return filename
    }

    static func deleteImage(named filename: String?) {
        guard let filename else { return }
        let url = imageURL(for: filename)
        try? fileManager.removeItem(at: url)
    }

    static func image(named filename: String?) -> UIImage? {
        guard let filename else { return nil }
        return UIImage(contentsOfFile: imageURL(for: filename).path)
    }

    private static func imageURL(for filename: String) -> URL {
        let baseDirectory = (try? makeDirectoryIfNeeded()) ?? fileManager.temporaryDirectory
        return baseDirectory.appendingPathComponent(filename)
    }

    private static func makeDirectoryIfNeeded() throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}

private extension UIImage {
    func resizedForDashboard(maxDimension: CGFloat = 1_600) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
