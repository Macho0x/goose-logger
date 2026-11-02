// Times this package. One untimed batch, then batches until the window
// elapses. The sink keeps the call alive.
// Build with clang on the revision before a change, then again after:
//   goose build -o logger-bench bench.goose --cc clang
//   ./logger-bench
// Row names stay fixed. TinyCC (goose bench.goose) is not a timing result.
// ponytail: a fixed window, not a sampled harness. Rows under a microsecond
// move from run to run; lengthen the window before trusting them.

import os;
import emit;
import levels;
import sanitize;

const short: u8[:] = "filled 1.5";
const hit: u8[:] = "https://api.telegram.org/bot123:ABC/sendMessage";
var long: u8[4096] = [0x61; 4096];

fn mark(b: u8, ok: bool) -> u64 {
    if !ok { return 0; }
    let v: u64 = b;
    return v + 1;
}

fn time_batch<F>(batch: i64, ms: i64) -> i64, u64 {
    var sink: u64 = 0;
    var k = 0;
    while k < batch {
        sink += F();
        k += 1;
    }
    var n: i64 = 0;
    var dt: i64 = 0;
    let end = clock_ns() + ms * 1000000;
    while true {
        let t0 = clock_ns();
        k = 0;
        while k < batch {
            sink += F();
            k += 1;
        }
        dt += clock_ns() - t0;
        n += batch;
        if clock_ns() >= end { break; }
    }
    return dt / n, sink;
}

fn row<F>(name: u8[:], batch: i64, ms: i64) -> u64 {
    let ns, part = time_batch(batch, ms, F);
    var line: u8[>..] = [];
    format(line, name);
    while line.len < 28 { line.push(' '); }
    format_int(line, ns, 10, 12, ' ');
    format(line, "\n");
    write_stdout(line);
    return part;
}

fn san_short() -> u64 {
    let t = sanitize::text(short);
    if t.len == 0 { return 0; }
    return mark(t[0], true);
}

fn san_hit() -> u64 {
    let t = sanitize::text(hit);
    if t.len == 0 { return 0; }
    return mark(t[0], true);
}

fn san_long() -> u64 {
    long[0] += 1;
    if long[0] < 'a' || long[0] > 'z' { long[0] = 'a'; }
    let t = sanitize::text(long);
    if t.len == 0 { return 0; }
    return mark(t[0], true);
}

fn rec_row() -> u64 {
    var out: u8[>..] = [];
    emit::record(out, 1700000000000000000, levels::Level.Info, "fill.goose", 8, short);
    if out.len == 0 { return 0; }
    return mark(out[0], true);
}

fn has(text: u8[:], needle: u8[:]) -> bool {
    if needle.len == 0 || needle.len > text.len { return false; }
    for i in 0..(text.len - needle.len + 1) {
        if text[i..i + needle.len] == needle { return true; }
    }
    return false;
}

fn ready() -> bool {
    let clean = sanitize::text(short);
    if clean != short { return false; }
    let red = sanitize::text(hit);
    if !has(red, "bot***") { return false; }
    var out: u8[>..] = [];
    emit::record(out, 0, levels::Level.Info, "fill.goose", 8, short);
    return has(out, "INFO") && has(out, "filled 1.5");
}

fn ::main() {
    if !ready() { print("bench FAIL"); exit(1); }
    write_stdout("operation                       ns/call\n");
    var sink: u64 = 0;
    sink += row("sanitize short", 8, 250, san_short);
    sink += row("sanitize telegram", 8, 250, san_hit);
    sink += row("sanitize 4KB miss", 1, 400, san_long);
    sink += row("emit record", 8, 250, rec_row);
    var tail: u8[>..] = [];
    format(tail, "sink ");
    format(tail, sink);
    format(tail, "\n");
    write_stdout(tail);
}
