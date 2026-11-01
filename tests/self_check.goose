import os;
import regex;
import logger from "..";
import logger.emit;
import logger.levels;
import logger.sanitize;

fn fail(why: u8[:]) {
    write_stdout(why);
    write_stdout("\n");
    exit(1);
}

fn has(text: u8[:], needle: u8[:]) -> bool {
    if needle.len == 0 || needle.len > text.len { return false; }
    for i in 0..(text.len - needle.len + 1) {
        var same = true;
        for j in 0..needle.len {
            if text[i + j] != needle[j] { same = false; }
        }
        if same { return true; }
    }
    return false;
}

fn repeat(c: u8, n: i64) -> u8[>..] {
    var s: u8[>..] = [];
    for i in 0..n { s.push(c); }
    return s;
}

fn self_check() -> bool {
    let tg = sanitize::text("https://api.telegram.org/bot123:ABC/sendMessage sk-abcdefghijklmnopqrstuvwxyz012345");
    if !has(tg, "bot***") || !has(tg, "OPENAI_SK_REDACTED") { return false; }

    let pg = sanitize::text("connect postgres://app:hunter2@db.internal/mydb");
    if !has(pg, "postgres://********@db.internal/mydb") || has(pg, "hunter2") { return false; }
    if sanitize::text("https://token@host/x") != "https://token@host/x" { return false; }

    let bearer = sanitize::text("Bearer opaque-secret");
    if !has(bearer, "Bearer ********") || has(bearer, "opaque-secret") { return false; }
    let basic = sanitize::text("Basic dXNlcjpwYXNz");
    if !has(basic, "Basic ********") || has(basic, "dXNlcjpwYXNz") { return false; }
    let header = sanitize::text("Authorization: Bearer opaque-secret");
    if !has(header, "authorization: ********") || has(header, "opaque-secret") { return false; }
    if sanitize::text("Basic tier") != "Basic tier" { return false; }
    if sanitize::text("prompt_tokens=62") != "prompt_tokens=62" { return false; }
    if sanitize::text("the Token bucket algorithm") != "the Token bucket algorithm" { return false; }
    if sanitize::text("sk-abc") != "sk-abc" { return false; }
    if sanitize::text("eyJhbGciOi.eyJzdWIi.Sflabc") != "eyJhbGciOi.eyJzdWIi.Sflabc" { return false; }

    var jwt: u8[>..] = [];
    jwt.append("eyJ");
    jwt.append(repeat('A', 40));
    jwt.push('.');
    jwt.append(repeat('B', 40));
    jwt.push('.');
    jwt.append(repeat('C', 40));
    if jwt.len < 100 { return false; }
    if sanitize::text(jwt) != "JWT_REDACTED" { return false; }

    let auth2 = sanitize::text("authorization: Basic dXNlcjpwYXNz");
    if !has(auth2, "authorization: ********") || has(auth2, "dXNlcjpwYXNz") { return false; }

    var token: u8[>..] = [];
    token.append("1234567890:");
    token.append(repeat('A', 35));
    if sanitize::text(token) != "TELEGRAM_BOT_TOKEN_REDACTED" { return false; }
    var beside: u8[>..] = [];
    beside.append("leaked ");
    beside.append(token);
    beside.append(" next");
    let beside_out = sanitize::text(beside);
    if !has(beside_out, "TELEGRAM_BOT_TOKEN_REDACTED") || has(beside_out, token) { return false; }
    if !has(beside_out, "leaked ") || !has(beside_out, " next") { return false; }
    var url: u8[>..] = [];
    url.append("https://api.telegram.org/bot");
    url.append(token);
    url.append("/sendMessage");
    let url_out = sanitize::text(url);
    if !has(url_out, "bot***") || has(url_out, token) || has(url_out, "TELEGRAM_BOT_TOKEN_REDACTED") { return false; }
    if sanitize::text("123:ABC") != "123:ABC" { return false; }

    if sanitize::field("telegram_bot_token", "123456:ABCDEF") != "***" { return false; }
    if sanitize::field("prompt_tokens", "62") != "62" { return false; }
    if sanitize::field("completion_tokens", "62") != "62" { return false; }
    if sanitize::field("lane_key", "62") != "62" { return false; }

    var hex64 = repeat('a', 32);
    hex64.append(repeat('b', 32));
    var longer = repeat('f', 65);
    var mixed: u8[>..] = [];
    mixed.append("k=");
    mixed.append(hex64);
    mixed.append(" HYPERLIQUID_PK=deadbeef TELEGRAM_BOT_TOKEN=123:ABC ");
    mixed.append(longer);
    mixed.append(" prompt_tokens=62 {\"token\":\"supersecretvalue\"}");
    let mixed_out = sanitize::text(mixed);
    if !has(mixed_out, "HEX_SECRET_REDACTED") || has(mixed_out, hex64) { return false; }
    if !has(mixed_out, "HYPERLIQUID_PK=********") || has(mixed_out, "deadbeef") { return false; }
    if !has(mixed_out, "TELEGRAM_BOT_TOKEN=********") || has(mixed_out, "123:ABC") { return false; }
    if !has(mixed_out, longer) || !has(mixed_out, "prompt_tokens=62") { return false; }
    if !has(mixed_out, "\"token\":\"********\"") || has(mixed_out, "supersecretvalue") { return false; }

    var line: u8[>..] = [];
    emit::begin(line, "FILL");
    emit::field(line, "brain", "glm");
    emit::field(line, "symbol", "BTC");
    if !has(line, "tag=FILL") || line[0..8] != "tag=FILL" { return false; }
    if !has(line, "symbol=BTC") { return false; }
    if emit::include_run(levels::Level.Debug) != true || emit::include_run(levels::Level.Trace) != false { return false; }
    if levels::name(levels::Level.Info) != "INFO" || levels::name(levels::Level.Fatal) != "FATAL" { return false; }
    if levels::enabled(levels::Level.Debug, levels::Level.Info) { return false; }
    if !levels::enabled(levels::Level.Info, levels::Level.Info) || !levels::enabled(levels::Level.Error, levels::Level.Info) { return false; }
    if !levels::enabled(levels::Level.Fatal, levels::Level.Fatal) { return false; }

    var order: u8[>..] = [];
    emit::begin(order, "ORDER_SENT");
    emit::field(order, "brain", "glm");
    emit::field(order, "symbol", "BTC");
    emit::field(order, "packet_id", "p1");
    emit::field(order, "cloid", "abc");
    var tag_at = -1;
    var brain_at = -1;
    var sym_at = -1;
    var pkt_at = -1;
    var cloid_at = -1;
    for i in 0..(order.len - 3) {
        if order[i..i + 4] == "tag=" { tag_at = i; }
        if i + 6 <= order.len && order[i..i + 6] == "brain=" { brain_at = i; }
        if i + 7 <= order.len && order[i..i + 7] == "symbol=" { sym_at = i; }
        if i + 10 <= order.len && order[i..i + 10] == "packet_id=" { pkt_at = i; }
        if i + 6 <= order.len && order[i..i + 6] == "cloid=" { cloid_at = i; }
    }
    if !(tag_at >= 0 && tag_at < brain_at) { return false; }
    if !(brain_at < sym_at && sym_at < pkt_at && pkt_at < cloid_at) { return false; }

    var stamped: u8[>..] = [];
    emit::stamp(stamped, 1700000000123456789);
    if stamped != "20231114 221320.123456789" { return false; }
    var rec: u8[>..] = [];
    emit::record(rec, 1700000000123456789, levels::Level.Info, "order.goose", 40, order);
    if rec != "[20231114 221320.123456789] [INFO] [order.goose:40] [tag=ORDER_SENT brain=glm symbol=BTC packet_id=p1 cloid=abc]" { return false; }

    let err = "https://api.telegram.org/bot123456:ABCDEF/sendMessage: connection failed";
    let hook = "https://discord.com/api/webhooks/123456789/SECRET-TOKEN";
    let masked_err = sanitize::text(err);
    let masked_hook = sanitize::text(hook);
    if !has(masked_err, "https://api.telegram.org/bot***/sendMessage") || has(masked_err, "ABCDEF") { return false; }
    if !has(masked_hook, "https://discord.com/api/webhooks/***/***") || has(masked_hook, "SECRET-TOKEN") { return false; }

    var open: u8[>..] = [];
    var got: u8[>..] = [];
    emit::write_parts(open, got, "ureq sending https://api.telegram.org/bot123456:ABCDEF");
    emit::write_parts(open, got, "/sendMessage\n");
    emit::write_parts(open, got, "https://discord.com/api/webhooks/123/abc-DEF\n");
    emit::finish(open, got);
    if got != "ureq sending https://api.telegram.org/bot***/sendMessage\nhttps://discord.com/api/webhooks/***/***\n" { return false; }

    let spec = emit::filter_spec("ureq::unit=debug,ureq=trace,ureqx=debug,trading_bot=info");
    if spec != "ureqx=debug,trading_bot=info,ureq=warn,rustls=warn,hyper=warn,h2=warn,tungstenite=warn,reqwest=warn" { return false; }

    if emit::canonical_symbol("  BTC") != "BTC" { return false; }
    if emit::canonical_symbol("\xf0\x9f\x9a\x80 BTC") != "BTC" { return false; }
    var quoted: u8[>..] = [];
    emit::quote(quoted, "a b");
    if quoted != "\"a b\"" { return false; }
    let rid = emit::run_id();
    if rid.len != 40 { return false; }
    return true;
}

fn ::main() {
    if self_check() { print("logger ok"); }
    else { fail("logger"); }
}
