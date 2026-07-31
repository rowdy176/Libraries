# Romanizer

A tiny utility library for converting numbers into Roman numerals.

Currently only supports converting integers to Roman numerals.

## API

### `Romanizer.ToRoman(Number: number): string`

Converts a number into its Roman numeral representation.

The input is rounded to the nearest whole number and clamped between `1` and `3999`, as traditional Roman numerals do not represent values outside that range.


#### Design choices

* Values are rounded to the nearest integer before conversion.
* Inputs are clamped to the range `1` <-> `3999`.