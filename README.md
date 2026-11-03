<p align="center">
  <img src="logo.png" alt="A goose holding an open log book" width="220">
</p>

<h1 align="center">goose-logger</h1>

<p align="center">
  Process log lines for <a href="https://github.com/aardappel/goose">Goose</a><br>
  <strong>0.3.4</strong> · <a href="LICENSE">Apache-2.0</a>
</p>

One line per event:

```text
[2023-11-14 22:13:20.123456789 UTC] [INFO] [fill.goose:8] [filled]
```

The clock is Unix time, so the stamp is UTC. The six levels are `levels::Level`: `Trace`, `Debug`, `Info`, `Warn`, `Error`, `Fatal`. The printed token is still `[INFO]`. Goose does not record the call site, so the file and the row are arguments. A value with a space, a quote, or `=` is quoted. Secrets in the text are masked the same way as the trading bot's process log, and so is a PEM private key, a BIP-39 phrase, and a Stripe secret key.

## Example

```goose
import logger;

fn fill() {
    logger::info("fill.goose", 8, "filled");
}
```

```text
[2023-11-14 22:13:20.123456789 UTC] [INFO] [fill.goose:8] [filled]
```

`logger::trace`, `debug`, `info`, `warn`, `error`, and `fatal` each take the file, the row, and the text. `import logger` loads them. The stamp is the time of the call. The line above is that call at `1700000000123456789`.

A field line names its own values:

```goose
import logger.emit;
import logger.levels;

fn fill(symbol: u8[:]) {
    var body: u8[>..] = [];
    emit::begin(body, "FILL");
    emit::field(body, "symbol", symbol);
    emit::write(levels::Level.Info, "fill.goose", 12, body);
}
```

```text
[2023-11-14 22:13:20.123456789 UTC] [INFO] [fill.goose:12] [tag=FILL symbol=BTC]
```

`emit::record` fills a buffer you own when the line goes somewhere else. Call `levels::enabled` first when a floor should drop the line. `import logger.levels` loads the six names. `import logger.sanitize` loads the redaction on its own.

## Check

```sh
goose tests/self_check.goose
```

A good run prints `logger ok`.

## Benchmarks

`bench.goose` times this package. The row names stay fixed, so a clang run before a change and a clang run after it compare.

```sh
goose build -o logger-bench bench.goose --cc clang
./logger-bench
```

`goose bench.goose` runs in TinyCC. That is not a timing result. Numbers depend on the machine, so this page does not publish them.

## License

Apache-2.0. Free and open to everyone. The terms are in [LICENSE](LICENSE).
