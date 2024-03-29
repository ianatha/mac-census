//
//  macctl_Inventory.swift
//  i3
//
//  Created by Ian Atha on 2/6/18.
//  Copyright © 2018 Ian Atha. All rights reserved.
//

import Foundation

protocol MamabearInventoryListener {
    func workStarted(steps: Int)
    func stepStarted(text: String)
    func stepCompleted()
    func workCompleted(webContinuationSuccess: Bool, webContinuationResult: [String: Any])
}

class MamabearInventory {
    var listener: MamabearInventoryListener
    var backendURL: String
    var extraInfo: Dictionary<String, String>

    init(listener: MamabearInventoryListener, backendURL: String, extraInfo: Dictionary<String, String>) {
        self.listener = listener
        self.backendURL = backendURL

        self.extraInfo = extraInfo
    }

    let executor = CachedExecutor()

    func system_profile(category: String, name: String) -> String {
        let profile = executor.exec(cmd: "/usr/sbin/system_profiler", args: [category]).map({ $0.components(separatedBy: ": ") })

        let result = profile.filter({ $0[0].range(of: name) != nil }).map({ $0[1] })

        return result[0]
    }

    func users() -> [String] {
        return executor.exec(cmd: "/bin/ls", args: ["/Users"]).filter({ $0 != "Guest" && $0 != "Shared" })
    }

    func software_version() -> String {
        let sw_vers = executor.exec(cmd: "/usr/bin/sw_vers", args: [])
        let sw_vers_parsed = sw_vers.map { (x: String) -> String in
            let parts: [String] = x.components(separatedBy: ":")
            if parts.count == 2 {
                return parts[1].trimmingCharacters(in: NSCharacterSet.whitespaces)
            } else {
                return ""
            }
        }

        return sw_vers_parsed.joined(separator: " ")
    }

    //    func your_first_name() -> String {
    //        return self.representedObject as! String;
    //    }

    func transmitInventory(url: String, parameters: [String: Any], completion: @escaping (Bool, [String: Any]) -> ()) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = try! JSONSerialization.data(withJSONObject: parameters)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://github.com/MamabearIO/i3/tree/v" + (Bundle.main.infoDictionary?["CFBundleVersion"] as! String? ?? ""), forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
            if let data = data, let status = (response as? HTTPURLResponse)?.statusCode {
                if status == 200 {
                    if let _json = try? (JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]), let json = _json {
                        completion(true, json)
                    } else {
                        completion(false, ["err": "The backend didn't respond with a valid response."])
                    }
                } else {
                    completion(false, ["err": "The backend responded with HTTP error \(status)."])
                }
            } else {
                completion(false, ["err": error!.localizedDescription])
            }
        }

        task.resume()
    }

    func current_time() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ";
        return formatter.string(from: Date())
    }

    func start() {
        let inventory_data_spec: Dictionary<String, () -> Any> = [
            "software_version": { self.software_version() },
            "model_id":         { self.system_profile(category: "SPHardwareDataType", name: "Model Identifier") },
            "serial_number":    { self.system_profile(category: "SPHardwareDataType", name: "Serial Number (system)") },
            "processor_name":   { self.system_profile(category: "SPHardwareDataType", name: "Processor Name") },
            "processor_speed":  { self.system_profile(category: "SPHardwareDataType", name: "Processor Speed") },
            "processor_cores":  { self.system_profile(category: "SPHardwareDataType", name: "Total Number of Cores") },
            "memory":           { self.system_profile(category: "SPHardwareDataType", name: "Memory") },
            "hardware_uuid":    { self.system_profile(category: "SPHardwareDataType", name: "Hardware UUID") },
            "boot_rom_version": { self.system_profile(category: "SPHardwareDataType", name: "Boot ROM Version") },
            "smc_version":      { self.system_profile(category: "SPHardwareDataType", name: "SMC Version (system)") },
            "users":            { self.users() },
            "storage_capacity": { self.system_profile(category: "SPStorageDataType", name: "Capacity") },
            "osx_installation_date": {""},
            "osx_fulldiskencryption": {""},
            "osx_screensaver": {""},
            "osx_firmwarepassword": {""},
        ]

        var inventory = Dictionary<String, Any>()

        DispatchQueue.main.async {
            self.listener.workStarted(steps: inventory_data_spec.count + 1)
        }

        for (name, closure) in inventory_data_spec {
            DispatchQueue.main.async {
                self.listener.stepStarted(text: name)
            }
            inventory[name] = closure()
        }

        DispatchQueue.main.async {
            self.listener.stepStarted(text: "Transmitting to mothership...")
        }

        self.transmitInventory(url: self.backendURL, parameters: inventory, completion: { (success, result) in
            DispatchQueue.main.async {
                self.listener.workCompleted(webContinuationSuccess: success, webContinuationResult: result)
            }
        })
    }
}
