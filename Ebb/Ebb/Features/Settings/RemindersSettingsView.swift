import SwiftData
import SwiftUI

struct RemindersSettingsView: View {
    @Bindable var reminderPreferences: ReminderPreferences

    @Environment(\.theme) private var theme
    @Environment(CycleService.self) private var cycleService
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var showTimePicker = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $reminderPreferences.lutealNudgeEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Luteal-window heads-up")
                        Text("A gentle nudge when your higher-risk luteal phase begins.")
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }
                .onChange(of: reminderPreferences.lutealNudgeEnabled) { _, _ in
                    rescheduleReminders()
                }

                Toggle(isOn: $reminderPreferences.dailyLogReminderEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily log reminder")
                        Text("Optional check-in at a time you choose.")
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }
                .onChange(of: reminderPreferences.dailyLogReminderEnabled) { _, _ in
                    rescheduleReminders()
                }

                if reminderPreferences.lutealNudgeEnabled || reminderPreferences.dailyLogReminderEnabled {
                    Button {
                        showTimePicker = true
                    } label: {
                        LabeledContent("Reminder time") {
                            Text(reminderPreferences.reminderTimeLabel)
                                .foregroundStyle(theme.muted)
                        }
                    }
                }
            } header: {
                Text("Nudges")
            }

            Section {
                Toggle(isOn: $reminderPreferences.pauseDuringMigraine) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pause nudges during a migraine")
                        Text("When a migraine is logged, reminders stay quiet until it's over.")
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }
                .onChange(of: reminderPreferences.pauseDuringMigraine) { _, _ in
                    rescheduleReminders()
                }
            } header: {
                Text("Mid-migraine")
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.base)
        .foregroundStyle(theme.text)
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTimePicker) {
            ReminderTimePickerSheet(preferences: reminderPreferences) {
                rescheduleReminders()
            }
        }
        .task {
            rescheduleReminders()
        }
    }

    private func rescheduleReminders() {
        Task {
            let overlay = cycleService.makeOverlay(from: entries)
            await ReminderScheduler.reschedule(
                input: ReminderScheduler.ScheduleInput(
                    preferences: reminderPreferences,
                    overlay: overlay,
                    entries: entries,
                    now: .now
                )
            )
        }
    }
}

private struct ReminderTimePickerSheet: View {
    @Bindable var preferences: ReminderPreferences
    var onSave: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date

    init(preferences: ReminderPreferences, onSave: @escaping () -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        var components = DateComponents()
        components.hour = preferences.reminderHour
        components.minute = preferences.reminderMinute
        _selectedTime = State(initialValue: Calendar.current.date(from: components) ?? .now)
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                "Reminder time",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .background(theme.base)
            .foregroundStyle(theme.text)
            .navigationTitle("Reminder time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                        preferences.reminderHour = parts.hour ?? ReminderPreferences.defaultReminderHour
                        preferences.reminderMinute = parts.minute ?? ReminderPreferences.defaultReminderMinute
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        RemindersSettingsView(reminderPreferences: ReminderPreferences())
    }
    .environment(\.theme, .plumEmber)
    .environment(CycleService(provider: MockCycleDataProvider.lutealSample()))
    .modelContainer(for: SymptomEntry.self, inMemory: true)
}
