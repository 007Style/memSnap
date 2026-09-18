import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// AutoKillRulesView.swift — List, toggle, add, and delete auto-kill rules
// ═══════════════════════════════════════════════════════════════════════════════

struct AutoKillRulesView: View {

    @ObservedObject private var manager = AutoKillManager.shared

    @State private var showAddSheet  = false
    @State private var newName       = ""
    @State private var newThreshold  = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── Section header ────────────────────────────────────────────────
            HStack {
                Text("Auto-Kill Rules")
                    .font(DS.fontTitle)
                    .foregroundStyle(DS.textPrimary)
                Spacer()
                Button {
                    newName      = ""
                    newThreshold = ""
                    showAddSheet = true
                } label: {
                    Label("Add Rule", systemImage: "plus.circle")
                        .font(DS.fontCaption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DS.pressureNormal)
            }

            // ── Rules list ────────────────────────────────────────────────────
            if manager.rules.isEmpty {
                Text("No rules configured")
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach($manager.rules) { $rule in
                    RuleRow(rule: $rule) {
                        delete(rule: rule)
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .background(DS.surface)
        .cornerRadius(DS.cornerRadius)
        .sheet(isPresented: $showAddSheet) {
            AddRuleSheet(name: $newName, threshold: $newThreshold) {
                commitAdd()
            }
        }
    }

    // MARK: - Helpers

    private func delete(rule: AutoKillRule) {
        manager.rules.removeAll { $0.id == rule.id }
    }

    private func commitAdd() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let mb = Double(newThreshold.trimmingCharacters(in: .whitespaces)),
              mb > 0
        else { return }

        let rule = AutoKillRule(
            id:          UUID(),
            processName: trimmed,
            thresholdMB: mb,
            enabled:     true
        )
        manager.rules.append(rule)
        showAddSheet = false
    }
}

// MARK: - RuleRow

private struct RuleRow: View {
    @Binding var rule: AutoKillRule
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $rule.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.7)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(rule.processName)
                    .font(DS.fontLabel)
                    .foregroundStyle(rule.enabled ? DS.textPrimary : DS.textMuted)
                    .lineLimit(1)

                Text("≥ \(String(format: "%.0f", rule.thresholdMB)) MB")
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textMuted)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.pressureCritical)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AddRuleSheet

private struct AddRuleSheet: View {
    @Binding var name:      String
    @Binding var threshold: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(threshold.trimmingCharacters(in: .whitespaces)).map { $0 > 0 } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Auto-Kill Rule")
                .font(DS.fontTitle)
                .foregroundStyle(DS.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Process name")
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textMuted)
                TextField("e.g. Safari", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(DS.fontLabel)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Kill when RSS exceeds (MB)")
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textMuted)
                TextField("e.g. 2000", text: $threshold)
                    .textFieldStyle(.roundedBorder)
                    .font(DS.fontLabel)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(DS.textMuted)

                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(DS.cardPadding)
        .frame(width: 300)
    }
}
