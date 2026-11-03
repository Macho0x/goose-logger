// trace, debug, info, warn, error, and fatal write one line. Each takes
// the file, the row, and the text. Import emit to build fields. Import
// sanitize for redaction on its own. `goose tests/self_check.goose` checks
// the line.

import emit;
import levels;
import sanitize;

namespace logger;

fn trace(file: u8[:], row: i64, text: u8[:]) { emit::write(levels::Level.Trace, file, row, text); }
fn debug(file: u8[:], row: i64, text: u8[:]) { emit::write(levels::Level.Debug, file, row, text); }
fn info(file: u8[:], row: i64, text: u8[:]) { emit::write(levels::Level.Info, file, row, text); }
fn warn(file: u8[:], row: i64, text: u8[:]) { emit::write(levels::Level.Warn, file, row, text); }
fn error(file: u8[:], row: i64, text: u8[:]) { emit::write(levels::Level.Error, file, row, text); }
fn fatal(file: u8[:], row: i64, text: u8[:]) { emit::write(levels::Level.Fatal, file, row, text); }

fn ::main() {
    print("goose tests/self_check.goose");
}
