import Foundation

/// Object that represent the Serial Terminal. It keeps track of the logs that were received
/// Logs are cleaned up when connecting to a new printer
class Terminal {
    
    enum Filter {
        case temperature
        case sd
    }
    
    private let MAX_LOG_SIZE = 200
    
    /// Keeps unfiltered entries
    var logs = Array<String>()
    /// Log that holds filtered entries. Use only when filters is not empty
    var filteredLog = Array<String>()
    /// Filter to use for appending entries to filteredLog
    var filters = Array<Filter>() { didSet {
        // Clean up filteredLogs
        filteredLog.removeAll()
        if !filters.isEmpty {
            // Parse existing log to recreate filtered one
            appendEntriesFilteredLog(entries: logs)
        }
        } }
    
    /// Notification that we are about to connect to OctoPrint
    func websocketNewConnection() {
        // Clean up the logs since we are starting from scratch
        logs.removeAll()
        filteredLog.removeAll()
    }

    /// Notification that we connected to OctoPrint via websockets
    func websocketConnected() {
        // Clean up the logs since we are starting from scratch
        logs.removeAll()
        filteredLog.removeAll()
    }
    
    /// Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        if let newLogs = event.logs {
            if newLogs.isEmpty {
                // Nothing to do here
                return
            }
            // Append new entries to log
            appendLogEntries(log: &logs, newEntries: newLogs)

            if !filters.isEmpty {
                appendEntriesFilteredLog(entries: newLogs)
            }
        }
    }

    // MARK: - Private functions
    
    fileprivate func appendEntriesFilteredLog(entries: Array<String>) {
        // Filter our entries that do not pass filters
        let newEntries = entries.filter { (entry: String) -> Bool in
            for filter in filters {
                switch filter {
                case Filter.temperature:
                    if let _ = entry.range(of: #"(Send: (N\d+\s+)?M105)|(Recv:\s+(ok\s+((P|B|N)\d+\s+)*)?(B|T\d*):\d+)"#, options: .regularExpression, range: nil, locale: nil) {
                        return false
                    }
                case Filter.sd:
                    if let _ = entry.range(of: #"(Send: (N\d+\s+)?M27)|(Recv: SD printing byte)|(Recv: Not SD printing)"#, options: .regularExpression, range: nil, locale: nil) {
                        return false
                    }
                }
            }
            return true
        }
        // Append filtered entries to filtered log
        appendLogEntries(log: &filteredLog, newEntries: newEntries)
    }
    
    fileprivate func appendLogEntries(log: inout Array<String>, newEntries: Array<String>) {
        // Make sure that we do not go over the limit of logs we keep in memory
        if log.count + newEntries.count > MAX_LOG_SIZE {
            let toDeleteCount = log.count + newEntries.count - MAX_LOG_SIZE
            if toDeleteCount >= log.count {
                log.removeAll()
            } else {
                log.removeFirst(toDeleteCount)
            }
        }
        
        // Add new logs
        log.append(contentsOf: newEntries)
    }
}
