// One log line: tag, version, run id, then fields. Values that contain
// spaces or quotes are quoted. symbol drops a leading glyph. Trace omits
// the run id. A line split across writes is sanitized once it is complete.

import os;
import levels;
import sanitize;

namespace emit;

extern fn getpid() -> i32;

fn hex_digit(v: u64) -> u8 {
    let n = v & 0x0f;
    if n < 10 { return '0' + (n as! u8); }
    return 'a' + ((n - 10) as! u8);
}

fn push_hex(out: u8[>..]&, v: u64, width: i64) {
    var i = width - 1;
    while i >= 0 {
        let shift = i * 4;
        out.push(hex_digit(v >> (shift as! u64)));
        i -= 1;
    }
}

fn run_id() -> u8[>..] {
    var out: u8[>..] = [];
    let ns = time_ns();
    let n: u64 = if ns < 0 { 0 } else { ns as! u64 };
    push_hex(out, 0, 16);
    push_hex(out, n, 16);
    let pid: u64 = getpid() as u64;
    push_hex(out, pid, 8);
    return out;
}

fn include_run(level: levels::Level) -> bool { return level != levels::Level.Trace; }

fn push_width(out: u8[>..]&, n: i64, width: i64) {
    var v = n;
    if v < 0 { v = 0; }
    var tmp: u8[20] = ['0'; 20];
    var i = 19;
    while v > 0 && i >= 0 {
        tmp[i] = '0' + ((v % 10) as! u8);
        v = v / 10;
        i -= 1;
    }
    var from = 20 - width;
    if from < 0 { from = 0; }
    var real = 0;
    while real < 20 && tmp[real] == '0' { real += 1; }
    if real == 20 { real = 19; }
    if real < from { from = real; }
    for k in from..20 { out.push(tmp[k]); }
}

fn civil(days: i64) -> i64, i64, i64 {
    let z = days + 719468;
    let era = z / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    var y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    var m = mp - 9;
    if mp < 10 { m = mp + 3; }
    if m <= 2 { y += 1; }
    return y, m, d;
}

fn stamp(out: u8[>..]&, ns: i64) {
    var t = ns;
    if t < 0 { t = 0; }
    let sec = t / 1000000000;
    let frac = t % 1000000000;
    let days = sec / 86400;
    let sod = sec % 86400;
    let y, mo, d = civil(days);
    push_width(out, y, 4);
    push_width(out, mo, 2);
    push_width(out, d, 2);
    out.push(' ');
    push_width(out, sod / 3600, 2);
    push_width(out, (sod % 3600) / 60, 2);
    push_width(out, sod % 60, 2);
    out.push('.');
    push_width(out, frac, 9);
}

fn record(out: u8[>..]&, ns: i64, level: levels::Level, file: u8[:], row: i64, text: u8[:]) {
    let clean = sanitize::text(text);
    out.push('[');
    stamp(out, ns);
    out.append("] [");
    out.append(levels::name(level));
    out.append("] [");
    out.append(file);
    out.push(':');
    push_width(out, row, 1);
    out.append("] [");
    out.append(clean);
    out.push(']');
}

fn trim(s: u8[:]) -> u8[:] {
    var a = 0;
    var b = s.len;
    while a < b && (s[a] == ' ' || s[a] == '\t') { a += 1; }
    while b > a && (s[b - 1] == ' ' || s[b - 1] == '\t') { b -= 1; }
    return s[a..b];
}

fn alnum(c: u8) -> bool {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
}

fn canonical_symbol(s: u8[:]) -> u8[>..] {
    let t = trim(s);
    var sp = -1;
    for i in 0..t.len {
        if t[i] == ' ' { sp = i; break; }
    }
    if sp > 0 {
        var graphic = false;
        for i in 0..sp {
            if !alnum(t[i]) { graphic = true; }
        }
        if graphic {
            var rest: u8[>..] = [];
            rest.append(trim(t[sp + 1..]));
            return rest;
        }
    }
    var out: u8[>..] = [];
    out.append(t);
    return out;
}

fn needs_quote(s: u8[:]) -> bool {
    if s.len == 0 { return true; }
    for c in s {
        if c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '=' || c == '"' || c == '\'' {
            return true;
        }
    }
    return false;
}

fn quote(out: u8[>..]&, s: u8[:]) {
    if !needs_quote(s) { out.append(s); return; }
    out.push('"');
    for c in s {
        if c == '\\' || c == '"' { out.push('\\'); }
        out.push(c);
    }
    out.push('"');
}

fn skip_key(key: u8[:]) -> bool {
    return key == "tag" || key == "run_id" || key == "version";
}

fn begin(out: u8[>..]&, tag: u8[:]) {
    let clean_tag = sanitize::text(tag);
    out.append("tag=");
    quote(out, clean_tag);
}

fn field(out: u8[>..]&, key: u8[:], value: u8[:]) {
    if skip_key(key) { return; }
    var shown: u8[>..] = [];
    if key == "symbol" { shown = canonical_symbol(value); }
    else { shown.append(value); }
    let clean = sanitize::field(key, shown);
    out.push(' ');
    out.append(key);
    out.push('=');
    quote(out, clean);
}

fn write_parts(open: u8[>..]&, out: u8[>..]&, buf: u8[:]) {
    open.append(buf);
    while true {
        var end = -1;
        for i in 0..open.len {
            if open[i] == '\n' { end = i; break; }
        }
        if end < 0 { return; }
        let clean = sanitize::text(open[0..end + 1]);
        out.append(clean);
        var rest: u8[>..] = [];
        if end + 1 < open.len { rest.append(open[end + 1..]); }
        open.resize(0, 0);
        open.append(rest);
    }
}

fn finish(open: u8[>..]&, out: u8[>..]&) {
    if open.len == 0 { return; }
    let clean = sanitize::text(open);
    out.append(clean);
    open.resize(0, 0);
}

fn http_name(target: u8[:]) -> bool {
    return target == "ureq" || target == "rustls" || target == "hyper"
        || target == "h2" || target == "tungstenite" || target == "reqwest"
        || (target.len > 6 && target[0..6] == "ureq::")
        || (target.len > 8 && target[0..8] == "rustls::")
        || (target.len > 7 && target[0..7] == "hyper::")
        || (target.len > 4 && target[0..4] == "h2::")
        || (target.len > 13 && target[0..13] == "tungstenite::")
        || (target.len > 9 && target[0..9] == "reqwest::");
}

fn directive_target(d: u8[:]) -> u8[:] {
    var n = d.len;
    for i in 0..d.len {
        if d[i] == '=' || d[i] == '[' { n = i; break; }
    }
    return trim(d[0..n]);
}

fn filter_spec(rust_log: u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    var i = 0;
    var first = true;
    while i <= rust_log.len {
        var j = i;
        while j < rust_log.len && rust_log[j] != ',' { j += 1; }
        let part = trim(rust_log[i..j]);
        if part.len != 0 && !http_name(directive_target(part)) {
            if !first { out.push(','); }
            out.append(part);
            first = false;
        }
        i = j + 1;
        if j >= rust_log.len { break; }
    }
    let pins = "ureq=warn,rustls=warn,hyper=warn,h2=warn,tungstenite=warn,reqwest=warn";
    if !first { out.push(','); }
    out.append(pins);
    return out;
}
