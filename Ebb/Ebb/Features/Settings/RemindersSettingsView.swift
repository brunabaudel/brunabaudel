import SwiftData
import SwiftUI

struct RemindersSettingsView: View {
    let schema: SchemaConfig
    @Bindable var reminderPreferences: ReminderPreferences

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(CycleService.self) private var cycleService
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var entries: [SymptomEntry]

    @State private var showTimePicker = false
    #if DEBUG
    @State private var lutealTestMessage: String?
    #endif

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

            #if DEBUG
            lutealTestSection
            #endif
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

    #if DEBUG
    private var lutealTestSection: some View {
        Section {
            Text("Inserts a 5-day period starting 14 days ago so today is luteal day 15. Then set reminder time 1–2 minutes ahead, turn off daily log, and background the app.")
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .listRowBackground(theme.surface)

            Button("Seed mock period for luteal test") {
                seedLutealTestData()
            }

            if let lutealTestMessage {
                Text(lutealTestMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.ok)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(theme.surface)
            }
        } header: {
            Text("Testing")
        }
    }

    private func seedLutealTestData() {
        lutealTestMessage = nil
        do {
            let result = try LutealTestDataSeeder.seed(
                schemaVersion: schema.schemaVersion,
                modelContext: modelContext,
                cycleService: cycleService
            )
            let dateLabel = result.nextLutealStart.formatted(date: .abbreviated, time: .omitted)
            lutealTestMessage =
                "Seeded. Today is cycle day \(result.cycleDayToday) (\(result.phaseToday.displayName)). Next luteal heads-up: \(dateLabel)."
            rescheduleReminders()
        } catch {
            lutealTestMessage = error.localizedDescription
        }
    }
    #endif
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
        RemindersSettingsView(
            schema: try! SchemaConfig.load(),
            reminderPreferences: ReminderPreferences()
        )
    }
    .environment(\.theme, .plumEmber)
    .environment(CycleService(provider: MockCycleDataProvider.lutealSample()))
    .modelContainer(for: SymptomEntry.self, inMemory: true)
}
