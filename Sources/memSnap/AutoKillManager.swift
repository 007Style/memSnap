import Combine
import Darwin
import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// AutoKillManager.swift — Rule-based auto-SIGTERM with cooldown + event log
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - AutoKillRule

struct AutoKillRule: Codable, Identifiable {
    let id:          UUID
    var processName: String
    var thresholdMB: Double
    var enabled:     Bool
}

// MARK: - AutoKillEvent

struct AutoKillEvent: Identifiable {
    let id:           UUID = UUID()
    let timestamp:    Date
    let processName:  String
    let rssAtKillMB:  Double
}

// MARK: - AutoKillManager

@MainActor
final class AutoKillManager: ObservableObject {

    static let shared = AutoKillManager()

    // ── Published ─────────────────────────────────────────────────────────────
    @Published var rules: [AutoKillRule] = [] {
        didSet { saveRules() }
    }
    @Published var recentEvents: [AutoKillEvent] = []

    // ── Private ───────────────────────────────────────────────────────────────
    private var cancellables = Set<AnyCancellable>()

    /// Cooldown table: PID → last kill date. Skip if < 60 s has elapsed.
    private var cooldowns: [Int: Date] = [:]

    private static let defaultsKey = "memSnap.autoKillRules"

    // MARK: - Init

    private init() {
        loadRules()
        // Defer subscription one run-loop turn to avoid re-entrant deadlock
        // during static initialisation of ProcessMonitor.shared.
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
        print("[memSnap] AutoKillManager initialised")
    }

    // MARK: - Subscription

    private func start() {
        ProcessMonitor.shared.$topProcesses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processes in
                self?.evaluate(processes)
            }
            .store(in: &cancellables)
    }

    // MARK: - Rule evaluation

    private func evaluate(_ processes: [ProcessEntry]) {
        let now = Date()

        for rule in rules where rule.enabled {
            // Case-insensitive contains match
            guard let match = processes.first(where: {
                $0.name.range(of: rule.processName, options: .caseInsensitive) != nil
            }) else { continue }

            let rssMB = Double(match.rssBytes) / 1_048_576.0
            guard rssMB > rule.thresholdMB else { continue }

            let pid = match.id

            // Cooldown: skip if killed within the last 60 s
            if let lastKill = cooldowns[pid],
               now.timeIntervalSince(lastKill) < 60 {
                continue
            }

            fireKill(pid: pid, processName: match.name, rssAtKillMB: rssMB)
        }
    }

    // MARK: - Kill + log

    private func fireKill(pid: Int, processName: String, rssAtKillMB: Double) {
        print("[memSnap] AutoKill: sending SIGTERM to \(processName) (pid \(pid)) at \(String(format: "%.1f", rssAtKillMB)) MB")

        kill(pid_t(pid), SIGTERM)

        let event = AutoKillEvent(
            timestamp:   Date(),
            processName: processName,
            rssAtKillMB: rssAtKillMB
        )

        recentEvents.insert(event, at: 0)
        if recentEvents.count > 20 {
            recentEvents.removeLast()
        }

        cooldowns[pid] = Date()
    }

    // MARK: - Persistence

    private func loadRules() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([AutoKillRule].self, from: data)
        else { return }
        rules = decoded
    }

    private func saveRules() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
