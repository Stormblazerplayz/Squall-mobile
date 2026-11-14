import SwiftUI

/// List of routines that wake a teammate up on a schedule.
struct RoutinesView: View {
    @EnvironmentObject private var store: SquallStore

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Routines")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                        Spacer()
                        if let routine = store.routines.first(where: { $0.run != nil }) {
                            // A routine running right now, counting up on the Lock Screen.
                            LockScreenButton(kind: .routine, compact: true) {
                                LiveActivities.shared.startRoutine(routine, bot: store.bot(routine.botID))
                            }
                        }
                        Button {
                            store.path.append(.newRoutine)
                        } label: {
                            Label("New", systemImage: "plus")
                        }
                        .buttonStyle(GhostButtonStyle(height: 38, expand: false, fontSize: 14, sidePadding: 14))
                    }
                    Text("A routine wakes a teammate on a schedule to check in or pick up work.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.sub)

                    if store.routines.isEmpty {
                        emptyState
                    } else {
                        // iPad: routines sit side by side in a grid that fills the screen.
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: isWide ? 360 : 280), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(store.routines) { routine in
                                RoutineRow(routine: routine)
                            }
                        }
                    }
                }
                .padding(16)
                .readableColumn(isWide ? Theme.wideWidth : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge")
                .font(.system(size: 36))
                .foregroundStyle(Theme.sub)
            Text("No routines yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text("A routine wakes a teammate on a schedule to check in or pick up work.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
            Button("New routine") { store.path.append(.newRoutine) }
                .buttonStyle(FilledButtonStyle(fill: store.accent))
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct RoutineRow: View {
    @EnvironmentObject private var store: SquallStore
    let routine: Routine

    var body: some View {
        let bot = store.bot(routine.botID)
        HStack(alignment: .top, spacing: 12) {
            if let bot {
                Sphere(bot: bot, size: 40)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(bot?.name ?? "Teammate")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text(routine.task)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.text)
                Text(routine.whenTitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
                if routine.isOn {
                    Text(routine.nextRunText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.greenText)
                } else {
                    Text("Off")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { routine.isOn },
                set: { store.setRoutine(routine.id, isOn: $0) }
            ))
            .labelsHidden()
            .tint(store.accent)
            .accessibilityLabel("Turn on \(bot?.name ?? "this") routine")
        }
        .padding(14)
        .glassCard(radius: 18, tint: bot?.hex, strength: 0.1)
        .contextMenu {
            Button("Delete routine", systemImage: "trash", role: .destructive) {
                store.deleteRoutine(routine.id)
            }
        }
    }
}
