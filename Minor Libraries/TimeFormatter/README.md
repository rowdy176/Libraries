# TimeFormatter

A tiny utility library for formatting durations into readable strings.

Right now it only includes the `xmxs` format (`1h 2m 5s`), but more formatting styles may be added over time if I or others find them useful.

## API

### `TimeFormatter.xmxs(Time: number | string): string?`

Formats a duration in seconds into a compact string using:

* `w` -> weeks
* `d` -> days
* `h` -> hours
* `m` -> minutes
* `s` -> seconds

Accepts either a number or a numeric string.

Returns `nil` if the value can't be converted to a number or is negative.

Decimal values are rounded down before formatting.

<b>Design choices</b>
* Returns `"0s"` for `0`.
* Omits units with a value of `0`.