import SwiftUI

struct VehicleStatusView: View {
    let status: VehicleStatus

    var body: some View {
        VStack(spacing: 24) {
            // Batterie
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(Int(status.battery.stateOfChargePercent))")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(socColor)
                Text("%")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(socColor)
                    .padding(.bottom, 12)
            }

            // Autonomie
            HStack(spacing: 4) {
                Image(systemName: "road.lanes")
                Text("Autonomie estimée : \(Int(status.battery.estimatedRangeKm)) km")
                    .font(.title3.weight(.medium))
            }
            .foregroundStyle(.secondary)

            // État
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(status.charging.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Puissance de charge
            if let power = status.battery.chargingPowerKW {
                Label("\(power, specifier: "%.1f") kW en cours", systemImage: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var socColor: Color {
        switch status.battery.stateOfChargePercent {
        case 50...:  return .green
        case 25..<50: return .orange
        default:     return .red
        }
    }

    private var statusColor: Color {
        status.charging.isActive ? .green : .secondary
    }
}
