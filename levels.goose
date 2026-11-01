// The six process-log levels, in order. Trace is the lowest and Fatal
// is the highest. enabled is true when level is at least minimum.
// name is the token printed inside the brackets, such as INFO.

namespace levels;

enum Level { Trace, Debug, Info, Warn, Error, Fatal }

fn name(level: Level) -> u8[:] {
    if level == Level.Trace { return "TRACE"; }
    if level == Level.Debug { return "DEBUG"; }
    if level == Level.Info { return "INFO"; }
    if level == Level.Warn { return "WARN"; }
    if level == Level.Error { return "ERROR"; }
    return "FATAL";
}

fn rank(level: Level) -> i64 {
    if level == Level.Trace { return 0; }
    if level == Level.Debug { return 1; }
    if level == Level.Info { return 2; }
    if level == Level.Warn { return 3; }
    if level == Level.Error { return 4; }
    return 5;
}

fn enabled(level: Level, minimum: Level) -> bool {
    return rank(level) >= rank(minimum);
}
