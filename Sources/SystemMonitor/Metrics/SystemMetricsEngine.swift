import Foundation
import Combine

/// Owns the single polling timer for the whole app — every status item and
/// the panel observe the same `sample`, so we never sample twice per tick.
/// Interval drops from the user's chosen 1/2/5s to a fixed 5s whenever the
/// panel is closed, per the design's battery-conservation note.
///
/// Process sampling is the one part that stops entirely with the panel
/// closed: it costs one `proc_pidinfo` per live PID (~600 syscalls a tick)
/// and feeds only the panel's "maiores consumos" list, which nobody can
/// see while the panel is shut. Everything else is a handful of syscalls
/// and keeps running, because the status item draws it.
final class SystemMetricsEngine: ObservableObject {
    static let shared = SystemMetricsEngine()

    @Published private(set) var sample = MetricSample()

    private let cpuSampler = CPUSampler()
    private let memorySampler = MemorySampler()
    private let diskSampler = DiskSampler()
    private let diskIOSampler = DiskIOSampler()
    private let networkSampler = NetworkSampler()
    private let thermalSampler = ThermalSampler()
    private let batterySampler = BatterySampler()
    private let processSampler = ProcessSampler()

    private let settings = AppSettings.shared
    private var timer: DispatchSourceTimer?
    private var cancellables: Set<AnyCancellable> = []
    // Serial on purpose: .global(qos:) is a concurrent queue, and a tick
    // that overruns the sampling interval would let the next firing start
    // on another thread while previousLoad/previousTimes/lastBytesIn are
    // still being mutated by the first — a data race on plain Swift
    // collections. A dedicated serial queue guarantees ticks never overlap.
    private let timerQueue = DispatchQueue(label: "com.estevaofonseca.systemmonitor.metrics-timer", qos: .utility)

    // Owned by the timer queue, like the samplers' internal state — tick()
    // reading the @Published `sample` (written on main) for the previous
    // history was a cross-thread read of a Swift array.
    private var cpuHistory: [Double] = []
    private var criticalTracker = CriticalTracker()
    private let historyLimit = 30
    // Snapshot of settings.showProcesses for tick() to read on the timer
    // queue; the @Published property itself belongs to the main thread.
    private var includeProcesses: Bool
    // Same deal for isPanelOpen, which is written on main.
    private var panelIsOpen = false
    // Set when the process baseline has just been seeded and there's no
    // meaningful delta yet — see restartProcessSampling().
    private var processesPending = false

    var isPanelOpen = false {
        didSet {
            guard oldValue != isPanelOpen else { return }
            let open = isPanelOpen
            // Enqueued before the timer is rescheduled below, and the queue
            // is serial, so the baseline is always in place before the
            // fire-immediately tick runs.
            timerQueue.async { [weak self] in
                guard let self else { return }
                self.panelIsOpen = open
                if open { self.restartProcessSampling() }
            }
            rescheduleTimer(fireImmediately: isPanelOpen)
        }
    }

    private init() {
        includeProcesses = settings.showProcesses

        settings.$sampleInterval
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rescheduleTimer(fireImmediately: false) }
            .store(in: &cancellables)
        settings.$showProcesses
            .dropFirst()
            .sink { [weak self] show in
                guard let self else { return }
                // Hop to the timer queue: tick() mutates the samplers'
                // internal state, which is only ever touched there.
                self.timerQueue.async {
                    self.includeProcesses = show
                    if show { self.restartProcessSampling() }
                    self.tick()
                }
            }
            .store(in: &cancellables)

        // fireImmediately gives the first sample right away, on the timer
        // queue — calling tick() directly here would run it on main,
        // racing the first scheduled firing.
        rescheduleTimer(fireImmediately: true)
    }

    private func rescheduleTimer(fireImmediately: Bool) {
        timer?.cancel()
        let interval = isPanelOpen ? settings.sampleInterval.rawValue : 5.0
        let source = DispatchSource.makeTimerSource(queue: timerQueue)
        let start: DispatchTime = fireImmediately ? .now() : .now() + interval
        source.schedule(deadline: start, repeating: interval)
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        timer = source
    }

    private func tick() {
        let cpu = cpuSampler.sample()
        let memory = memorySampler.sample()
        let disk = diskSampler.sample()
        let diskIO = diskIOSampler.sample()
        let network = networkSampler.sample()
        let thermal = thermalSampler.sample()
        let battery = batterySampler.sample()
        let processes = sampleProcesses()

        cpuHistory.append(cpu.totalPercent)
        if cpuHistory.count > historyLimit {
            cpuHistory.removeFirst(cpuHistory.count - historyLimit)
        }

        var next = MetricSample()
        next.cpuPercent = cpu.totalPercent
        next.cpuUserPercent = cpu.userPercent
        next.cpuSystemPercent = cpu.systemPercent
        next.cpuHistory = cpuHistory
        next.cpuModel = cpu.model
        next.cpuCoreCount = cpu.coreCount

        next.memoryUsedGB = memory.usedGB
        next.memoryTotalGB = memory.totalGB
        next.memoryActiveGB = memory.activeGB
        next.memoryWiredGB = memory.wiredGB
        next.memoryCompressedGB = memory.compressedGB
        next.swapUsedGB = memory.swapUsedGB
        next.swapTotalGB = memory.swapTotalGB

        next.diskUsedGB = disk.usedGB
        next.diskTotalGB = disk.totalGB
        next.diskReadRate = diskIO.readRate
        next.diskWriteRate = diskIO.writeRate

        next.networkDownRate = network.downRate
        next.networkUpRate = network.upRate

        next.thermalState = thermal

        next.batteryPercent = battery.percent
        next.batteryTimeRemainingMinutes = battery.minutesRemaining
        next.isCharging = battery.isCharging

        next.topProcesses = processes.byCPU
        next.topMemoryProcesses = processes.byMemory
        next.processesPending = includeProcesses && panelIsOpen && processesPending
        next.isCritical = criticalTracker.update(cpuPercent: cpu.totalPercent)

        processesPending = false

        DispatchQueue.main.async { [weak self] in
            self?.sample = next
        }
    }

    /// Top consumers, but only while the panel is actually showing them.
    ///
    /// The tick right after the baseline is seeded returns nothing: its
    /// delta would span the few milliseconds since the seed, and dividing
    /// by that gives percentages in the thousands. One interval later
    /// there's a real elapsed time to divide by.
    private func sampleProcesses() -> ProcessSampler.Result {
        guard includeProcesses, panelIsOpen, !processesPending else { return .empty }
        return processSampler.sample(limit: 4)
    }

    #if DEBUG
    /// Test seam: stops the timer and holds a reading of someone else's
    /// choosing. Used to draw the README's panel image from fixed numbers,
    /// so regenerating it produces the same picture every time — and so a
    /// screenshot of the process list doesn't publish whatever the author
    /// happened to have open. Debug-only; the release build has no way in.
    func freezeForTesting(_ frozen: MetricSample) {
        timer?.cancel()
        timer = nil
        if Thread.isMainThread {
            sample = frozen
        } else {
            DispatchQueue.main.sync { self.sample = frozen }
        }
    }

    /// Puts the engine back to work after `freezeForTesting`.
    func unfreezeForTesting() {
        rescheduleTimer(fireImmediately: true)
    }
    #endif

    /// Records where every process's CPU time stands right now, without
    /// producing a reading. Called when the panel opens (or the setting is
    /// switched on), since the sampler has been idle and has nothing to
    /// diff against.
    private func restartProcessSampling() {
        processSampler.seed()
        processesPending = true
    }
}
