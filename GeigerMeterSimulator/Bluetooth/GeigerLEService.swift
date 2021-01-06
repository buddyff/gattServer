//
//  GeigerLEService.swift
//  GeigerMeterSimulator
//
//  Created by Pablo Caif on 18/2/18.
//  Copyright © 2018 Pablo Caif. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol GeigerLEServiceDelegate: class {
    func serviceNotify(message: String)
}

public class GeigerLEService: NSObject {
    
    private var peripheralManager: CBPeripheralManager?
    private var geigerMeterService: CBMutableService?
    private var radiationSensorChar: CBMutableCharacteristic?
    
    var randomService: CBMutableService?
    private let randomServiceID = "D82BB947-5FC7-48F5-8D59-A60494E4CB3E"
    
    private let enabledModeCharID = "a457c45a-e464-4aa5-a6cb-1adf4e98a549"
    private let zonesCharID = "d8768fa9-30df-42d4-be06-c780225845b3"
    private let ventsCharID = "408B7B23-E8EC-4323-A913-0A276F8959CA"
    private let rvIDCharID = "27841C71-F5B8-4AED-A837-EC17AB657C20"
    private let settingsCharID = "7D6FCD08-3416-4575-94A4-7069B6CC74AD"
    private let displaySettingsCharID = "4079043D-E363-43BA-AC2F-42E9F8698524"
    private let commandsCharID = "7B26E39D-7DAC-45FF-BC86-EE2A5BCDAFCC"
    private let alertsCharID = "0456DE03-9F25-4961-8740-72EEAF987A2E"
    private let rvConfigCharID = "7CF17FC0-6B54-4E5E-94F1-CB5037C6C1E2"
    private let currentEventCharID = "8C761318-A8A3-429D-9FC0-E31CF9321537"
    private let nextEventCharID = "C76AA19C-DE31-4CF7-B466-CE27AFB212CC"
    private let modesCharID = "C286A7FF-5FBF-407D-8983-C5812C9BAF04"
    private let eventsCharID = "61CB43BC-9BBC-41B7-A55C-8D080D2D4EC7"
    
    private var enabledModeChar: CBMutableCharacteristic?
    private var zonesChar: CBMutableCharacteristic?
    private var ventsChar: CBMutableCharacteristic?
    private var rvIDChar: CBMutableCharacteristic?
    private var settingsChar: CBMutableCharacteristic?
    private var displaySettingsChar: CBMutableCharacteristic?
    private var commandsChar: CBMutableCharacteristic?
    private var alertsChar: CBMutableCharacteristic?
    private var rvConfigChar: CBMutableCharacteristic?
    private var nextEventChar: CBMutableCharacteristic?
    private var currentEventChar: CBMutableCharacteristic?
    private var modesChar: CBMutableCharacteristic?
    private var eventsChar: CBMutableCharacteristic?
    
    private let geigerCommandCharID = "F35065D4-DE1D-4A50-B7D0-4AE378B7E51D"
    private var geigerCommandChar: CBMutableCharacteristic?
    
    public weak var delegate: GeigerLEServiceDelegate?
    
    private var timer :Timer?
    
    private var enabledMode: [String] = enabledModeConstant
    private var zones: [String] = zonesConstants
    private var vents: [String] = ventsConstants
    private var settings: [String] = settingsConstant
    private var displaySettings: [String] = displaySettingsConstant
    private var alerts: [String] = alertsConstant
    private var modes: [String] = modesConstant
    private var events: [String] = eventsConstant
    
    static let enabledModeConstant = ["1"]
    static let zonesConstants = ["312098095111", "103100095100"]
    static let ventsConstants = ["110909911011", "210910011002"]
    static let settingsConstant = ["SSID_2"]
    static let displaySettingsConstant = ["1111111"]
    static let alertsConstant = ["101018301234", "060210450234"]
    static let modesConstant = ["1100Sleep", "2107Wake", "3070Away", "4055Smart Vent", "5060Pet"]
    static let rvConfigConstant = "020205"
    static let nextEvent = "$"
    static let currentEvent = "$"
    //static let eventsConstant = ["0111111001045#1100", "3200#11#EventName", "$"] // event with 2 zones & 1 vent config, on week days at 10:45
    //static let eventsConstant = ["0100000110930#1100", "#11#EventName$"] // event with 1 zone & 1 vent config, on weekends at 09:30
    //static let eventsConstant = ["0100000110930##11#Ev", "entName$"] // event with only 1 vent config, on weekends at 09:30
    //static let eventsConstant = ["0100000110930#3200##", "EventName$"] // event with only 1 zone config, on weekends at 09:30
    static let eventsConstant = ["0100000110930#3200##", "WeekendEvent$", "0211111001045#1100", "3200#11#WeekEvent$"] // Two events
    
    private var isSendingEnabledMode: Bool = false
    private var isSendingZones: Bool = false
    private var isSendingVents: Bool = false
    private var isSendingSettings: Bool = false
    private var isSendingDisplaySettings: Bool = false
    private var isSendingAlerts: Bool = false
    private var isSendingRVConfig: Bool = false
    private var isSendingCurrentEvent: Bool = false
    private var isSendingNextEvent: Bool = false
    private var isSendingModes: Bool = false
    private var isSendingEvents: Bool = false


    ///Calling this function will attempt to start advertising the services
    ///as well as create the services and characteristics
    public func startAdvertisingPeripheral() {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        
        if peripheralManager?.state == .poweredOn {
            peripheralManager?.removeAllServices()
            setupServicesAndCharac()
            peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: randomServiceID)]])
            delegate?.serviceNotify(message: "Service started")
        }
        
    }

    ///Calling this function will stop advertising the services
    public func stopAdvertising() {
        timer?.invalidate()
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        geigerMeterService = nil
        radiationSensorChar = nil
        peripheralManager = nil
        delegate?.serviceNotify(message: "Service stopped")
    }
    
    private func setupServicesAndCharac() {
        createRandomResponseService()
    }
    
    private func createRandomResponseService() {
        randomService = CBMutableService(type: CBUUID(string: randomServiceID), primary: true)
        
        enabledModeChar = CBMutableCharacteristic(type: CBUUID(string: enabledModeCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        zonesChar = CBMutableCharacteristic(type: CBUUID(string: zonesCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        ventsChar = CBMutableCharacteristic(type: CBUUID(string: ventsCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        rvIDChar = CBMutableCharacteristic(type: CBUUID(string: rvIDCharID), properties: [.read, .notify], value: nil, permissions: .readable)
        settingsChar = CBMutableCharacteristic(type: CBUUID(string: settingsCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        displaySettingsChar = CBMutableCharacteristic(type: CBUUID(string: displaySettingsCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        commandsChar = CBMutableCharacteristic(type: CBUUID(string: commandsCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        alertsChar = CBMutableCharacteristic(type: CBUUID(string: alertsCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        rvConfigChar = CBMutableCharacteristic(type: CBUUID(string: rvConfigCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        nextEventChar = CBMutableCharacteristic(type: CBUUID(string: nextEventCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        currentEventChar = CBMutableCharacteristic(type: CBUUID(string: currentEventCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        modesChar = CBMutableCharacteristic(type: CBUUID(string: modesCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        eventsChar = CBMutableCharacteristic(type: CBUUID(string: eventsCharID), properties: [.writeWithoutResponse, .notify], value: nil, permissions: .writeable)
        
        randomService?.characteristics = [enabledModeChar!, zonesChar!, ventsChar!, rvIDChar!, settingsChar!, displaySettingsChar!, commandsChar!, alertsChar!, rvConfigChar!, nextEventChar!, currentEventChar!, modesChar!, eventsChar!]
        
        peripheralManager?.add(randomService!)
    }
    
    func notify(msg: String) {
        peripheralManager?.updateValue(Data(msg.utf8), for: commandsChar!, onSubscribedCentrals: nil)
    }
}

// MARK: CBPeripheralManagerDelegate
extension GeigerLEService: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral manager switched on\n")
            startAdvertisingPeripheral()
        case .poweredOff:
            print("Peripheral manager switched off\n")
            stopAdvertising()
        case .resetting:
            print("Peripheral manager reseting\n")
            stopAdvertising()
        case .unauthorized:
            print("Peripheral manager unauthorised\n")
        case .unknown:
            print("Peripheral manager unknown\n")
        case .unsupported:
            print("Peripheral manager unsoported\n")
        }
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("READY AGAIN")
        if isSendingEnabledMode {
            sendEnabledMode()
        } else if isSendingZones {
            sendZones()
        } else if isSendingVents {
            sendVents()
        } else if isSendingSettings {
            sendSettings()
        } else if isSendingDisplaySettings {
            sendDisplaySettings()
        } else if isSendingAlerts {
            sendAlerts()
        } else if isSendingRVConfig {
            sendRVConfig()
        } else if isSendingCurrentEvent {
            sendCurrentEvent()
        } else if isSendingNextEvent {
            sendNextEvent()
        } else if isSendingModes {
            sendModes()
        } else if isSendingEvents {
            sendEvents()
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        let message = "Central \(central.identifier.uuidString) subscribed"
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == rvIDChar?.uuid {
            var firstPart = Data("4b60b69d-0032-48a1-9".utf8)
            rvIDChar?.value = Data(bytes: &firstPart, count: firstPart.count)
            request.value = firstPart
            peripheral.respond(to: request, withResult: .success)
            peripheralManager?.updateValue(Data("657-ab0645c24fc1".utf8), for: rvIDChar!, onSubscribedCentrals: nil)
            print("SENT RV ID")
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        requests.forEach { request in
            //If the request is to write to the command characteristic we execute the command
            if request.characteristic.uuid == enabledModeChar?.uuid {
                isSendingEnabledMode = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendEnabledMode()
                    }
                }
            } else if request.characteristic.uuid == zonesChar?.uuid {
                isSendingZones = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendZones()
                    }
                }
            } else if request.characteristic.uuid == ventsChar?.uuid {
                isSendingVents = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendVents()
                    }
                }
            } else if request.characteristic.uuid == settingsChar?.uuid {
                isSendingSettings = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendSettings()
                    }
                }
            } else if request.characteristic.uuid == displaySettingsChar?.uuid {
                isSendingDisplaySettings = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendDisplaySettings()
                    } else {
                        var notifyMsg = String(data: data, encoding: .utf8)
                        notifyMsg?.removeFirst()
                        peripheralManager?.updateValue(notifyMsg!.data, for: displaySettingsChar!, onSubscribedCentrals: nil)
                    }
                }
            } else if request.characteristic.uuid == commandsChar?.uuid {
                if let data = request.value {
                    peripheralManager?.updateValue(data, for: commandsChar!, onSubscribedCentrals: nil)
                }
            } else if request.characteristic.uuid == alertsChar?.uuid {
                isSendingAlerts = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendAlerts()
                    }
                }
            } else if request.characteristic.uuid == rvConfigChar?.uuid {
                isSendingRVConfig = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendRVConfig()
                    }
                }
            } else if request.characteristic.uuid == currentEventChar?.uuid {
                isSendingCurrentEvent = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendCurrentEvent()
                    }
                }
            } else if request.characteristic.uuid == nextEventChar?.uuid {
                isSendingNextEvent = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendNextEvent()
                    }
                }
            } else if request.characteristic.uuid == modesChar?.uuid {
                isSendingModes = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendModes()
                    }
                }
            } else if request.characteristic.uuid == eventsChar?.uuid {
                isSendingEvents = true
                if let data = request.value {
                    let stringReceived = String(data: data, encoding: .utf8)
                    if stringReceived == "1" {
                        sendEvents()
                    }
                }
            }
        }
    }
    
    private func sendEnabledMode() {
        while !enabledMode.isEmpty {
            let enabledModeToSend = enabledMode.first
            if peripheralManager?.updateValue(Data(enabledModeToSend!.utf8), for: enabledModeChar!, onSubscribedCentrals: nil) == false {
                return
            } else {
                print("SENT ENABLED MODE WITH \(enabledModeToSend!)")
                enabledMode.remove(at: 0)
                if enabledMode.isEmpty {
                    isSendingEnabledMode = false
                    enabledMode = GeigerLEService.enabledModeConstant
                    break
                }
            }
        }
    }
    
    private func sendZones() {
        while !zones.isEmpty {
            let zoneToSend = zones.first
            if peripheralManager?.updateValue(Data(zoneToSend!.utf8), for: zonesChar!, onSubscribedCentrals: nil) == false {
                return
            } else {
                print("SENT ZONE WITH \(zoneToSend!)")
                zones.remove(at: 0)
                if zones.isEmpty {
                    isSendingZones = false
                    zones = GeigerLEService.zonesConstants
                    break
                }
            }
        }
    }
    
    private func sendVents() {
        while !vents.isEmpty {
            let ventToSend = vents.first
            if peripheralManager?.updateValue(Data(ventToSend!.utf8), for: ventsChar!, onSubscribedCentrals: nil) == false {
                return
            } else {
                print("SENT VENT WITH \(ventToSend!)")
                vents.remove(at: 0)
                if vents.isEmpty {
                    isSendingVents = false
                    vents = GeigerLEService.ventsConstants
                    break
                }
            }
        }
    }
    
    private func sendModes() {
        while !modes.isEmpty {
            let modeToSend = modes.first
            if peripheralManager?.updateValue(Data(modeToSend!.utf8), for: modesChar!, onSubscribedCentrals: nil) == false {
                return
            } else {
                print("SENT MODE \(modeToSend!)")
                modes.remove(at: 0)
                if modes.isEmpty {
                    isSendingModes = false
                    modes = GeigerLEService.modesConstant
                    break
                }
            }
        }
    }
    
    private func sendSettings() {
        while !settings.isEmpty {
            let settingToSend = settings.first
            if peripheralManager?.updateValue(Data(settingToSend!.utf8), for: settingsChar!, onSubscribedCentrals: nil) == false {
                return
            } else {
                print("SENT SETTING:  \(settingToSend!)")
                settings.remove(at: 0)
                if settings.isEmpty {
                    isSendingSettings = false
                    settings = GeigerLEService.settingsConstant
                    break
                }
            }
        }
    }
    
    private func sendDisplaySettings() {
        while !displaySettings.isEmpty {
            let settingToSend = displaySettings.first
            if peripheralManager?.updateValue(Data(settingToSend!.utf8), for: displaySettingsChar!, onSubscribedCentrals: nil) == false {
                return
            } else {
                print("SENT DISPLAY SETTING:  \(settingToSend!)")
                displaySettings.remove(at: 0)
                if displaySettings.isEmpty {
                    isSendingDisplaySettings = false
                    displaySettings = GeigerLEService.displaySettingsConstant
                    break
                }
            }
        }
    }
    
    private func sendAlerts() {
        while !alerts.isEmpty {
            let alertToSend = alerts.first
            if peripheralManager?.updateValue(Data(alertToSend!.utf8), for: alertsChar!, onSubscribedCentrals: nil) == false {
                return
            } else {
                print("SENT ALERT:  \(alertToSend!)")
                alerts.remove(at: 0)
                if alerts.isEmpty {
                    isSendingAlerts = false
                    alerts = GeigerLEService.alertsConstant
                    break
                }
            }
        }
    }
    
    private func sendRVConfig() {
        let config = GeigerLEService.rvConfigConstant
        
        if peripheralManager?.updateValue(Data(config.utf8), for: rvConfigChar!, onSubscribedCentrals: nil) == false {
            return
        } else {
            print("SENT RV CONFIG:  \(config)")
            isSendingRVConfig = false
        }
    }
    
    private func sendCurrentEvent() {
        let currentEvent = GeigerLEService.currentEvent
        
        if peripheralManager?.updateValue(Data(currentEvent.utf8), for: currentEventChar!, onSubscribedCentrals: nil) == false {
            return
        } else {
            print("SENT CURRENT EVENT:  \(currentEvent)")
            isSendingCurrentEvent = false
        }
    }
    
    private func sendNextEvent() {
        let nextEvent = GeigerLEService.nextEvent
        
        if peripheralManager?.updateValue(Data(nextEvent.utf8), for: nextEventChar!, onSubscribedCentrals: nil) == false {
            return
        } else {
            print("SENT NEXT EVENT:  \(nextEvent)")
            isSendingNextEvent = false
        }
    }
    
    private func sendEvents() {
        while !events.isEmpty {
            let eventToSend = events.first
            if peripheralManager?.updateValue(Data(eventToSend!.utf8), for: eventsChar!, onSubscribedCentrals: nil) == false {
                return
            } else {
                print("SENT EVENT: \(eventToSend)")
                events.remove(at: 0)
                if events.isEmpty {
                    isSendingEvents = false
                    events = GeigerLEService.eventsConstant
                    break
                }
            }
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("Did start advertising")
        if let errorAdvertising = error {
            print("Error advertising \(errorAdvertising.localizedDescription)")
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if error != nil {
            print("Error adding service=\(service.uuid) error=\(error!.localizedDescription)")
        } else {
            print("Service \(service.uuid) added")
        }
    }
}

enum GeigerCommand: UInt8 {
    case standBy = 0
    case on
}

extension StringProtocol {
    var data: Data { .init(utf8) }
}
