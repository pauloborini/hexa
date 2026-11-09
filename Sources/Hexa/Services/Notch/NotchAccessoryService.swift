// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import AppKit
import Combine
import CoreBluetooth
import IOBluetooth

/// The system monitor remains the only battery sampler. Native connection
/// notifications report an actual connection, independently of missing readings.
final class NotchAccessoryService: NSObject, CBCentralManagerDelegate {
    static let shared = NotchAccessoryService()
    var onMonitoringStateChanged: ((Bool) -> Void)?
    private var subscription: AnyCancellable?
    // Estado Bluetooth confinado à fila, inclusive callbacks e teardown.
    private let bluetoothQueue = DispatchQueue(label: "com.hexa.notch-accessories", qos: .utility)
    private var central: CBCentralManager?
    private var bluetoothGeneration: UUID?
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var batteryState = NotchAccessoryBatteryState()
    private var connectionState = NotchAccessoryConnectionState()
    private var active = false
    private var activationTime: TimeInterval = 0
    private var generation = UUID()
    private var pending: [(notice: NotchNotice, device: String, expiresAt: Date)] = []
    private var noticeWork: DispatchWorkItem?
    private override init() { super.init() }

    func syncWithPreferences() {
        guard NotchAccessorySupport.isEnabled() else { stop(); return }
        guard !active else {
            bluetoothQueue.async { [weak self] in self?.refreshBluetooth() }
            return
        }
        active = true
        activationTime = ProcessInfo.processInfo.systemUptime
        generation = UUID()
        let currentGeneration = generation
        bluetoothQueue.async { [weak self] in
            guard let self else { return }
            self.bluetoothGeneration = currentGeneration
            self.refreshBluetooth()
        }
        subscription = SystemMonitor.shared.$snapshot.map(\.peripheralBatterySample)
            .removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] sample in
                guard let self, self.active, self.generation == currentGeneration,
                      NotchAccessorySupport.isEnabled() else { return }
                self.pending.removeAll { queued in
                    queued.notice.level != nil && sample.devices.contains { device in
                        self.batteryState.isFresh(device, in: sample, observedAfter: self.activationTime)
                            && device.name == queued.device
                            && device.percent >= NotchAccessorySupport.recoveryThreshold
                    }
                }
                let text = FeatureStrings.notchActivities(L10n.shared.language)
                for device in self.batteryState.consume(sample, observedAfter: self.activationTime) {
                    self.enqueue(NotchNotice(event: .accessory, title: device.name,
                        detail: text.lowBattery + " · \(device.percent)%",
                        symbol: NotchAccessorySupport.symbol(for: device.kind, name: device.name),
                        level: Double(device.percent) / 100), device: device.name)
                }
            }
        onMonitoringStateChanged?(true)
    }

    func stop() {
        batteryState = NotchAccessoryBatteryState()
        suspend()
    }

    func suspend() {
        guard active else { return }
        active = false
        generation = UUID()
        subscription = nil
        bluetoothQueue.async { [weak self] in
            guard let self else { return }
            self.bluetoothGeneration = nil
            self.central = nil
            self.stopConnectionNotifications()
        }
        noticeWork?.cancel(); noticeWork = nil
        pending.removeAll()
        onMonitoringStateChanged?(false)
    }

    private func observeDisconnect(_ device: IOBluetoothDevice) {
        guard CBManager.authorization == .allowedAlways,
              let id = device.addressString, disconnectNotifications[id] == nil else { return }
        disconnectNotifications[id] = device.register(forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:)))
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        bluetoothQueue.async { [weak self] in
            guard let self, let generation = self.bluetoothGeneration, CBManager.authorization == .allowedAlways,
                  NotchAccessorySupport.isEnabled(), device.isConnected(),
                  NotchAccessorySupport.announcesConnection(majorClass: UInt32(device.deviceClassMajor)),
                  let id = device.addressString, self.connectionState.connected(id) else { return }
            self.observeDisconnect(device)
            guard let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }
            let symbol = NotchAccessorySupport.symbol(name: name, majorClass: UInt32(device.deviceClassMajor),
                                                      minorClass: UInt32(device.deviceClassMinor))
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, self.generation == generation,
                      NotchAccessorySupport.isEnabled() else { return }
                let text = FeatureStrings.notchActivities(L10n.shared.language)
                self.enqueue(NotchNotice(event: .accessory, title: text.connected, detail: name, symbol: symbol), device: name)
            }
        }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        bluetoothQueue.async { [weak self] in
            guard let self, let generation = self.bluetoothGeneration, CBManager.authorization == .allowedAlways,
                  NotchAccessorySupport.isEnabled(), !device.isConnected(), let id = device.addressString else { return }
            self.connectionState.disconnected(id)
            if let name = device.name {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.active, self.generation == generation else { return }
                    self.pending.removeAll { $0.device == name }
                }
            }
            self.disconnectNotifications.removeValue(forKey: id)?.unregister()
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) { refreshBluetooth() }

    private func refreshBluetooth() {
        guard bluetoothGeneration != nil, NotchAccessorySupport.isEnabled(),
              Permissions.hasUsageDescription("NSBluetoothAlwaysUsageDescription") else {
            stopConnectionNotifications()
            return
        }
        // Ligar a ilha não pede Bluetooth: o pedido vem de Permissions.requestBluetooth,
        // e o grant chega aqui no próximo sync.
        guard CBManager.authorization == .allowedAlways else {
            stopConnectionNotifications()
            return
        }
        // IOBluetooth só recebe grant concedido.
        if central == nil {
            central = CBCentralManager(delegate: self, queue: bluetoothQueue,
                                      options: [CBCentralManagerOptionShowPowerAlertKey: false])
            return
        }
        guard CBManager.authorization == .allowedAlways, central?.state == .poweredOn else {
            stopConnectionNotifications()
            return
        }
        guard connectNotification == nil else { return }
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).filter { $0.isConnected() }
        connectionState.establishBaseline(Set(devices.compactMap { $0.addressString }))
        devices.forEach(observeDisconnect)
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:)))
    }

    private func stopConnectionNotifications() {
        // Liberação de registros existentes também ocorre após revogação do grant.
        connectNotification?.unregister(); connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
        connectionState = NotchAccessoryConnectionState()
    }

    private func enqueue(_ notice: NotchNotice, device: String) {
        if pending.count >= 8 { pending.removeFirst() }
        pending.append((notice, device, Date().addingTimeInterval(30)))
        if noticeWork == nil { presentNext() }
    }

    private func presentNext() {
        noticeWork = nil
        pending.removeAll { $0.expiresAt <= Date() }
        guard active, NotchAccessorySupport.isEnabled(), let first = pending.first else { return }
        let notch = NotchService.shared
        if !notch.expanded, notch.captureControls == nil, notch.show(first.notice) { pending.removeFirst() }
        let work = DispatchWorkItem { [weak self] in self?.presentNext() }
        noticeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + NotchEvent.accessory.duration + 0.1, execute: work)
    }
}
