import SwiftUI

/// Hero timeline: solar-production curve in the background, task blocks slotted at their
/// start hour, each split-shaded (own-solar green vs. grid grey). Tap a block to select it.
struct DayTimeline: View {
    let curve: [PlanResult.CurvePoint]
    let tasks: [PlanResult.PlannedTask]
    let selected: String?
    let onTap: (String) -> Void

    private let startHour = 6
    private let endHour = 23           // axis 06:00–23:00
    private var span: Int { endHour - startHour }   // 17

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let curveH = h * 0.42
                let laneTop = curveH + 8
                let maxKw = max(1, curve.map(\.solarKw).max() ?? 1)
                let hourW = w / CGFloat(span)
                let lanes = layoutLanes(tasks)
                let laneH: CGFloat = 30
                ZStack(alignment: .topLeading) {
                    // solar curve area
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: curveH))
                        for pt in curve {
                            let x = CGFloat(pt.hour - startHour) * hourW
                            let y = curveH - CGFloat(pt.solarKw) / CGFloat(maxKw) * curveH
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        p.addLine(to: CGPoint(x: w, y: curveH))
                        p.closeSubpath()
                    }
                    .fill(Theme.green.opacity(0.16))

                    // task blocks
                    ForEach(Array(lanes.enumerated()), id: \.element.device) { _, item in
                        let x = CGFloat(item.task.startHour - startHour) * hourW
                        let bw = max(hourW * CGFloat(item.task.durationHours), 28)
                        let y = laneTop + CGFloat(item.lane) * (laneH + 6)
                        block(item.task, width: bw, height: laneH)
                            .frame(width: bw, height: laneH)
                            .offset(x: max(0, min(x, w - bw)), y: y)
                            .onTapGesture { onTap(item.task.device) }
                    }
                }
            }
            .frame(height: 168)
            HStack { Text("06"); Spacer(); Text("12"); Spacer(); Text("18"); Spacer(); Text("23") }
                .font(.system(size: 10)).foregroundStyle(Theme.subtle)
        }
    }

    private func block(_ t: PlanResult.PlannedTask, width: CGFloat, height: CGFloat) -> some View {
        let ownFrac = CGFloat(max(0, min(100, t.ownSharePct)) / 100)
        return ZStack(alignment: .leading) {
            // grid portion (full width), then own-solar portion overlaid from the left
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.grid.opacity(0.5))
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.green.opacity(0.85))
                .frame(width: max(8, width * ownFrac))
            HStack(spacing: 4) {
                Image(systemName: symbol(t.icon)).font(.system(size: 11, weight: .bold))
                Text(t.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
        }
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(selected == t.device ? Theme.ink : .clear, lineWidth: 2))
    }

    /// Greedy lane packing so overlapping blocks stack vertically.
    private struct Placed { let task: PlanResult.PlannedTask; let lane: Int; var device: String { task.device } }
    private func layoutLanes(_ tasks: [PlanResult.PlannedTask]) -> [Placed] {
        let sorted = tasks.sorted { $0.startHour < $1.startHour }
        var laneEnds: [Double] = []   // end hour per lane
        var out: [Placed] = []
        for t in sorted {
            let start = Double(t.startHour), end = start + t.durationHours
            let existingIdx = laneEnds.firstIndex(where: { $0 <= start })
            let lane: Int
            if let idx = existingIdx {
                laneEnds[idx] = end
                lane = idx
            } else {
                laneEnds.append(end)
                lane = laneEnds.count - 1
            }
            out.append(Placed(task: t, lane: lane))
        }
        return out
    }

    private func symbol(_ icon: String) -> String {
        switch icon {
        case "car":    return "car.fill"
        case "bowl":   return "dishwasher.fill"
        case "wash":   return "washer.fill"
        case "dryer":  return "dryer.fill"
        case "shower": return "shower.fill"
        case "flame":  return "flame.fill"
        default:       return "powerplug.fill"
        }
    }
}
