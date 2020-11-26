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
    
    private var enabledModeChar: CBMutableCharacteristic?
    private var zonesChar: CBMutableCharacteristic?
    private var ventsChar: CBMutableCharacteristic?
    private var rvIDChar: CBMutableCharacteristic?
    private var settingsChar: CBMutableCharacteristic?
    private var displaySettingsChar: CBMutableCharacteristic?
    private var commandsChar: CBMutableCharacteristic?
    private var alertsChar: CBMutableCharacteristic?
    
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
    
    static let enabledModeConstant = ["0"]
    static let zonesConstants = ["312098095111", "103100095100"]
    static let ventsConstants = ["11090991101", "21091001100"]
    static let settingsConstant = ["SSID_2"]
    static let displaySettingsConstant = ["1111111"]
    static let alertsConstant = ["101018301234", "060210450234"]
    
    private var isSendingEnabledMode: Bool = false
    private var isSendingZones: Bool = false
    private var isSendingVents: Bool = false
    private var isSendingSettings: Bool = false
    private var isSendingDisplaySettings: Bool = false
    private var isSendingAlerts: Bool = false


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
        
        randomService?.characteristics = [enabledModeChar!, zonesChar!, ventsChar!, rvIDChar!, settingsChar!, displaySettingsChar!, commandsChar!, alertsChar!]
        
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
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        let message = "Central \(central.identifier.uuidString) subscribed"
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == rvIDChar?.uuid {
            var firstPart = Data("27bffaeb-d0c5-47d4-a".utf8)
            rvIDChar?.value = Data(bytes: &firstPart, count: firstPart.count)
            request.value = firstPart
            peripheral.respond(to: request, withResult: .success)
            peripheralManager?.updateValue(Data("fa4-c1988f89e2b0".utf8), for: rvIDChar!, onSubscribedCentrals: nil)
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
