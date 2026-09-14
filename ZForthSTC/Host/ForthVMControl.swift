import Foundation

enum ForthVMControl {
    static func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            zforth_vm_start()
        }
    }

    static func stop() {
        zforth_vm_stop()
    }
}
