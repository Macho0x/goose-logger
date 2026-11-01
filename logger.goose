// Process log lines for a Goose program. Import emit for the line and
// sanitize for redaction. `goose tests/self_check.goose` checks both.

import emit;
import sanitize;

namespace logger;

fn ::main() {
    print("goose tests/self_check.goose");
}
