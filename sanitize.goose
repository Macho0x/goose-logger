// Redacts secrets in a log line. The rules are the ones in the trading
// bot's log sanitizer: line forms, then URLs, then query secrets, then
// token shapes. A field whose name contains a mask word becomes "***",
// except the authority and token-count names.

import regex;

namespace sanitize;

let re_user = regex::compile("([a-zA-Z][a-zA-Z0-9+.-]*)://[^:\\s/?#]+:[^@\\s]+@");
let re_tg_https = regex::compile("https://api\\.telegram\\.org/bot[^/ \\t\\n\\r]+");
let re_tg_http = regex::compile("http://api\\.telegram\\.org/bot[^/ \\t\\n\\r]+");
let re_slack_https = regex::compile("https://hooks\\.slack\\.com/services/[A-Za-z0-9]+/[A-Za-z0-9]+/[A-Za-z0-9]+");
let re_slack_http = regex::compile("http://hooks\\.slack\\.com/services/[A-Za-z0-9]+/[A-Za-z0-9]+/[A-Za-z0-9]+");
let re_query = regex::compile("(?i)([?&])(access_token|refresh_token|client_secret|api_key|apikey|secret|token)=[^& \\t\\n\\r]+");
let re_password = regex::compile("(?i)password[ \\t]*(:|=)[ \\t]*[^ \\t\\n\\r]+");
let re_bearer = regex::compile("(?i)bearer[ \\t]*(:|=)[ \\t]*[^ \\t\\n\\r]+");
let re_token = regex::compile("(?i)token[ \\t]*(:|=)[ \\t]*[^ \\t\\n\\r]+");
let re_auth = regex::compile("(?i)authorization[ \\t]*(:|=)[ \\t]*[^\\n]+");
let re_cookie = regex::compile("(?i)cookie[ \\t]*(:|=)[ \\t]*[^\\n]+");
let re_xapi = regex::compile("(?i)x[-_]api[-_]key[ \\t]*(:|=)[ \\t]*[^\\n]+");
let re_hl_test = regex::compile("(?i)HYPERLIQUID_TESTNET_PK[ \\t]*(:|=)[ \\t]*[^ \\t\\n\\r]+");
let re_hl_pk = regex::compile("(?i)HYPERLIQUID_PK[ \\t]*(:|=)[ \\t]*[^ \\t\\n\\r]+");
let re_tg_env = regex::compile("(?i)TELEGRAM_BOT_TOKEN[ \\t]*(:|=)[ \\t]*[^ \\t\\n\\r]+");
let re_disc_env = regex::compile("(?i)DISCORD_WEBHOOK_URL[ \\t]*(:|=)[ \\t]*[^ \\t\\n\\r]+");
let re_word = regex::compile("((?i)Bearer|Basic)[ \\t]+[A-Za-z0-9_\\-.+/=]{8,}");
let re_jwt = regex::compile("eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+");
let re_ghp = regex::compile("ghp_[A-Za-z0-9]+");
let re_gpat = regex::compile("github_pat_[A-Za-z0-9_]+");
let re_openai = regex::compile("sk-[A-Za-z0-9]{17,}");
let re_aws = regex::compile("AKIA[0-9A-Z]{16}");
let re_eth = regex::compile("0x[0-9a-fA-F]{64}");
let re_hex = regex::compile("[0-9A-Fa-f]{64}");
let re_bottoken = regex::compile("[0-9]{8,10}:[A-Za-z0-9_-]{35}");
let re_json = regex::compile("(?i)\"(token|secret|password|api_key)\"[ \\t]*:[ \\t]*\"[^\"]*\"");
let re_d0 = regex::compile("https://discord\\.com/api/webhooks/[0-9]+/[^/ \\t\\n\\r?#]+");
let re_d1 = regex::compile("https://discordapp\\.com/api/webhooks/[0-9]+/[^/ \\t\\n\\r?#]+");
let re_d2 = regex::compile("https://canary\\.discord\\.com/api/webhooks/[0-9]+/[^/ \\t\\n\\r?#]+");
let re_d3 = regex::compile("https://ptb\\.discord\\.com/api/webhooks/[0-9]+/[^/ \\t\\n\\r?#]+");
let re_d4 = regex::compile("http://discord\\.com/api/webhooks/[0-9]+/[^/ \\t\\n\\r?#]+");
let re_d5 = regex::compile("http://discordapp\\.com/api/webhooks/[0-9]+/[^/ \\t\\n\\r?#]+");
let re_d6 = regex::compile("http://canary\\.discord\\.com/api/webhooks/[0-9]+/[^/ \\t\\n\\r?#]+");
let re_d7 = regex::compile("http://ptb\\.discord\\.com/api/webhooks/[0-9]+/[^/ \\t\\n\\r?#]+");

fn lower_byte(c: u8) -> u8 {
    if c >= 'A' && c <= 'Z' { return c + 32; }
    return c;
}

fn has_ci(hay: u8[:], needle: u8[:]) -> bool {
    if needle.len == 0 { return true; }
    if needle.len > hay.len { return false; }
    for i in 0..(hay.len - needle.len + 1) {
        var same = true;
        for j in 0..needle.len {
            if lower_byte(hay[i + j]) != lower_byte(needle[j]) { same = false; }
        }
        if same { return true; }
    }
    return false;
}

fn passthrough(key: u8[:]) -> bool {
    return key == "previous_authority" || key == "current_authority" || key == "cache_authority"
        || key == "lane_key" || key == "bar_key"
        || key == "prompt_tokens" || key == "completion_tokens"
        || key == "reasoning_tokens" || key == "text_tokens";
}

fn mask_key(key: u8[:]) -> bool {
    if passthrough(key) { return false; }
    return has_ci(key, "password") || has_ci(key, "secret") || has_ci(key, "key")
        || has_ci(key, "token") || has_ci(key, "auth") || has_ci(key, "credential")
        || has_ci(key, "private") || has_ci(key, "ssn") || has_ci(key, "social")
        || has_ci(key, "credit") || has_ci(key, "card") || has_ci(key, "cvv")
        || has_ci(key, "pin") || has_ci(key, "api_key") || has_ci(key, "apikey")
        || has_ci(key, "api_secret") || has_ci(key, "apisecret");
}

fn word(c: u8) -> bool {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_';
}

fn hexdig(c: u8) -> bool {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

fn token_char(c: u8) -> bool {
    return word(c) || c == '-';
}

fn copy_gap(out: u8[>..]&, text: u8[:], at: i64, s: i64) {
    if s > at { out.append(text[at..s]); }
}

fn pass_repl(re: regex::Regex&, src: u8[:], repl: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        dst.append(repl);
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn pass_user(src: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re_user, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        dst.append(regex::group(caps, 1));
        dst.append("://********@");
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn pass_query(src: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re_query, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        dst.append(regex::group(caps, 1));
        let name = regex::group(caps, 2);
        for i in 0..name.len { dst.push(lower_byte(name[i])); }
        dst.append("=********");
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn pass_token(src: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re_token, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        if s > 0 && word(src[s - 1]) { dst.append(src[s..e]); }
        else { dst.append("token: ********"); }
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn pass_word(src: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re_word, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        if s > 0 && word(src[s - 1]) { dst.append(src[s..e]); }
        else {
            dst.append(regex::group(caps, 1));
            dst.append(" ********");
        }
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn pass_jwt(src: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re_jwt, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        if e - s >= 100 { dst.append("JWT_REDACTED"); }
        else { dst.append(src[s..e]); }
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn pass_hex(src: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re_hex, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        let bad_prev = s > 0 && (hexdig(src[s - 1]) || src[s - 1] == 'x' || src[s - 1] == 'X');
        let bad_next = e < src.len && hexdig(src[e]);
        if bad_prev || bad_next { dst.append(src[s..e]); }
        else { dst.append("HEX_SECRET_REDACTED"); }
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn pass_bot(src: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re_bottoken, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        let bad_prev = s > 0 && src[s - 1] >= '0' && src[s - 1] <= '9';
        let bad_next = e < src.len && token_char(src[e]);
        if bad_prev || bad_next { dst.append(src[s..e]); }
        else { dst.append("TELEGRAM_BOT_TOKEN_REDACTED"); }
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn pass_json(src: u8[:]) -> u8[>..] {
    var dst: u8[>..] = [];
    var at = 0;
    var any = false;
    regex::each_captures(re_json, src) { caps =>
        any = true;
        let s = caps.slots[0];
        let e = caps.slots[1];
        copy_gap(dst, src, at, s);
        dst.push('"');
        dst.append(regex::group(caps, 1));
        dst.append("\":\"********\"");
        at = e;
    }
    if !any { dst.append(src); }
    else if at < src.len { dst.append(src[at..]); }
    return dst;
}

fn discord(src: u8[:]) -> u8[>..] {
    let a = pass_repl(re_d0, src, "https://discord.com/api/webhooks/***/***");
    let b = pass_repl(re_d1, a, "https://discordapp.com/api/webhooks/***/***");
    let c = pass_repl(re_d2, b, "https://canary.discord.com/api/webhooks/***/***");
    let d = pass_repl(re_d3, c, "https://ptb.discord.com/api/webhooks/***/***");
    let e = pass_repl(re_d4, d, "http://discord.com/api/webhooks/***/***");
    let f = pass_repl(re_d5, e, "http://discordapp.com/api/webhooks/***/***");
    let g = pass_repl(re_d6, f, "http://canary.discord.com/api/webhooks/***/***");
    return pass_repl(re_d7, g, "http://ptb.discord.com/api/webhooks/***/***");
}

fn lines(src: u8[:]) -> u8[>..] {
    let a = pass_repl(re_password, src, "password: ********");
    let b = pass_repl(re_bearer, a, "bearer: ********");
    let c = pass_token(b);
    let d = pass_repl(re_auth, c, "authorization: ********");
    let e = pass_repl(re_cookie, d, "cookie: ********");
    let f = pass_repl(re_xapi, e, "x-api-key: ********");
    let g = pass_repl(re_hl_test, f, "HYPERLIQUID_TESTNET_PK=********");
    let h = pass_repl(re_hl_pk, g, "HYPERLIQUID_PK=********");
    let i = pass_repl(re_tg_env, h, "TELEGRAM_BOT_TOKEN=********");
    return pass_repl(re_disc_env, i, "DISCORD_WEBHOOK_URL=********");
}

fn urls(src: u8[:]) -> u8[>..] {
    let a = pass_user(src);
    let b = pass_repl(re_tg_https, a, "https://api.telegram.org/bot***");
    let c = pass_repl(re_tg_http, b, "http://api.telegram.org/bot***");
    let d = discord(c);
    let e = pass_repl(re_slack_https, d, "https://hooks.slack.com/services/***/***");
    return pass_repl(re_slack_http, e, "http://hooks.slack.com/services/***/***");
}

fn shapes(src: u8[:]) -> u8[>..] {
    let a = pass_word(src);
    let b = pass_jwt(a);
    let c = pass_repl(re_ghp, b, "GITHUB_PAT_REDACTED");
    let d = pass_repl(re_gpat, c, "GITHUB_PAT_REDACTED");
    let e = pass_repl(re_openai, d, "OPENAI_SK_REDACTED");
    let f = pass_repl(re_aws, e, "AWS_ACCESS_KEY_ID_REDACTED");
    let g = pass_repl(re_eth, f, "ETH_HEX_SECRET_REDACTED");
    let h = pass_hex(g);
    let i = pass_bot(h);
    return pass_json(i);
}

fn text(src: u8[:]) -> u8[>..] {
    return shapes(pass_query(urls(lines(src))));
}

fn field(key: u8[:], value: u8[:]) -> u8[>..] {
    if mask_key(key) {
        var masked: u8[>..] = [];
        masked.append("***");
        return masked;
    }
    return text(value);
}
