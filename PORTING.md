# Porting

The behavior source is `src/log` in the trading bot. The checks are the unit tests in `sanitizer.rs`, `emit.rs`, and `mod.rs`, rewritten in `tests/self_check.goose`.

## API

| Rust | Goose |
| --- | --- |
| `sanitize_log_string` | `sanitize::text` |
| `sanitize_value` on a string | `sanitize::field` |
| `LogLevel` | `levels::Level` (`Trace` through `Fatal`). `levels::name` prints `INFO`. `levels::enabled` compares two of them. |
| `format_line` | `emit::begin` and `emit::field` build the text. `emit::record` wraps it as `[time] [level] [file:row] [text]`. |
| `quote_value` | `emit::quote` |
| `canonical_symbol` | `emit::canonical_symbol` |
| `include_run_id` | `emit::include_run`. `Level.Trace` is the level that omits a run id when the caller adds one. |
| `generate_run_id` | `emit::run_id`. 32 hex digits of `time_ns`, then 8 hex digits of `getpid`. |
| `filter_spec` | `emit::filter_spec` |
| `LineSanitizer` | `emit::write_parts` and `emit::finish` |

## What is different

There is no `tracing` subscriber and no panic hook. `emit::filter_spec` still pins the HTTP crate names to `warn`.

The printed line is `[YYYY-MM-DD HH:MM:SS.nnnnnnnnn UTC] [LEVEL] [file:row] [text]`. The clock is Unix time, so the stamp is UTC. Goose has no call-site macro, so `file` and `row` are arguments. The old `version=` and `run_id=` prefix is not inserted. A caller that wants a run id puts it in the text.

The six levels are one enum. A caller cannot pass a string that is not a level. `0.1` never shipped.

`Value::Dict`, `Value::Arr`, `Value::Float`, and `Value::Rat` are text before they reach `emit::field`. A decimal uses `decimal::text`. A float that Rust would print without a dot keeps the trailing `.` the caller added. Nested pairs are separate `emit::field` calls.

Goose regex has no `^`, `$`, or `\b`. The hex run, the BotFather token, and the `token=` form check the byte on each side in the replacer. The tests cover the same strings as the Rust tests.

A split line is sanitized when the newline arrives. `emit::finish` masks whatever is still buffered. Goose has no destructor to do that on drop.

The notify hook is not in this package. `sanitize::text` is what both the log line and a later page would call, which is the masking the Rust test checks.
