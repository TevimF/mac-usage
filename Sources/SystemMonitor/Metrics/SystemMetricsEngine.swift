import Foundation
import Combine

/// Owns the single polling timer for the whole app — every status item and
/// the panel observe the same `sample`, so we never sample twice per tick.
/// Interval drops from the user's chosen 1/2/5s to a fixed 5s whenever the
/// panel is closed, per the design's battery-conservation note.
final class SystemMetricsEngine: ObservableObject {
    static let shared = SystemMetricsEngine()

    @Published private(set) var sample = MetricSample()

    private let cpuSampler = CPUSampler()
    private let memorySampler = MemorySampler()
    private let diskSampler = DiskSampler()
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

    private var criticalStreak = 0
    private let criticalThreshold = 90.0
    private let criticalStreakNeeded = 3
    private let historyLimit = 30

    var isPanelOpen = false {
        didSet {
            guard oldValue != isPanelOpen else { return }
            rescheduleTimer(fireImmediately: isPanelOpen)
        }
    }

    private init() {
        settings.$sampleInterval
            .dropFirst()
            .sink { [weak self] _ in self?.rescheduleTimer(fireImmediately: false) }
            .store(in: &cancellables)
        settings.$showProcesses
            .dropFirst()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)

        rescheduleTimer(fireImmediately: false)
        tick()
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
        let network = networkSampler.sample()
        let thermal = thermalSampler.sample()
        let battery = batterySampler.sample()
        let processes = settings.showProcesses
            ? processSampler.sample(limit: 4)
            : ProcessSampler.Result(byCPU: [], byMemory: [])

        if cpu.totalPercent >= criticalThreshold {
            criticalStreak += 1
        } else {
            criticalStreak = 0
        }

        var next = MetricSample()
        next.cpuPercent = cpu.totalPercent
        next.cpuUserPercent = cpu.userPercent
        next.cpuSystemPercent = cpu.systemPercent
        next.cpuHistory = appending(cpu.totalPercent, to: sample.cpuHistory)
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

        next.networkDownRate = network.downRate
        next.networkUpRate = network.upRate

        next.thermalCelsius = thermal.celsius
        next.thermalState = thermal.state
        next.fanRPM = thermal.fanRPM

        next.batteryPercent = battery.percent
        next.batteryTimeRemainingMinutes = battery.minutesRemaining
        next.isCharging = battery.isCharging

        next.topProcesses = processes.byCPU
        next.topMemoryProcesses = processes.byMemory
        next.isCritical = criticalStreak >= criticalStreakNeeded

        DispatchQueue.main.async { [weak self] in
            self?.sample = next
        }
    }

    private func appending(_ value: Double, to history: [Double]) -> [Double] {
        var next = history
        next.append(value)
        if next.count > historyLimit {
            next.removeFirst(next.count - historyLimit)
        }
        return next
    }
}
