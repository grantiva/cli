import Logging

public enum LoggingBootstrap {
    public static func bootstrap() {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .info
            return handler
        }
    }
}
