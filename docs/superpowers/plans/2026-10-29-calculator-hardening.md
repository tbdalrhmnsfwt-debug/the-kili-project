# Calculator Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the twelve calculator gaps ranked in the 2026-10-29 four-area review, starting with the five Important ones.

**Architecture:** The engine (`lib/features/calculator/engine/`) is Flutter-free, so every fix below is proven by the existing assertion harness `tool/verify_calculator_logic.dart`, extended with a failing check first. UI wiring (haptics, persistence, dialogs) is proven by `dart analyze` plus reading, because no Flutter test runner exists on this device.

**Tech Stack:** Dart 3.13 (ARM64 SDK at `work/dartsdk/dart-sdk`), Flutter app at 3.x.

**Spec:** `docs/superpowers/specs/…` — none; the authority is the user-approved gap review of 2026-10-29 (findings 4.1–4.12 in the conversation and the four-area report).

## Global Constraints

- **Run tests like this** (plain `dart run` is killed silently, exit 255, inside this device's sandbox; `dart compile exe` works):
  ```bash
  export TMPDIR=/data/data/com.termux/files/usr/tmp
  SDK=/data/data/com.termux/files/home/the-kili-project/work/dartsdk/dart-sdk
  $SDK/bin/dart compile exe tool/verify_calculator_logic.dart -o $TMPDIR/calcverify.exe && $TMPDIR/calcverify.exe
  ```
  Expected on success: `OK — <N> checks passed.` Exit code 0.
- **Analyze like this:** `$SDK/bin/dart analyze lib/features/calculator tool/verify_calculator_logic.dart` — expected `No issues found!`.
- Format only touched files: `$SDK/bin/dart format <paths>` (never `dart format lib test`; a memory rule, ~200 unrelated files).
- No new dependencies.
- Arabic user-facing strings, Latin digits in results.
- Commit per task; do not push.

## Task 1: Session variable `E` is shadowed by Euler's constant

**Files:** `lib/features/calculator/engine/parser.dart:166`, `tool/verify_calculator_logic.dart`

- [ ] Add `verifyVariables()` to the harness: with `variables: {'E': EvalValue.integer(7)}`, `evaluate('E+1').displayValue == '8'`; `evaluate('e').displayValue == '2.71828182846'`; `evaluate('E').displayValue == '7'`.
- [ ] Run — expect RED on `E+1` (actual 3.71828182846).
- [ ] Change the guard to case-sensitive constant matching: `if (raw == 'e') return const ConstantExpr('e');`.
- [ ] Run — expect GREEN. Commit.

## Task 2: Negative shift count crashes BASE-N

**Files:** `lib/features/calculator/engine/base_n.dart:156-167`, harness

- [ ] Add checks: `throwsCalc(() => applyBaseOperation(BigInt.from(5), BigInt.from(-3), BaseOperation.shiftLeft), 'negative shift', kind: CalcErrorKind.argument)` and the same for `shiftRight`.
- [ ] Run — expect a crash or wrong failure (ArgumentError escapes).
- [ ] Reject `shift < 0` with `CalcError(CalcErrorKind.argument, detail: 'الإزاحة لازم تكون صفر أو أكتر.')` before shifting, in both branches.
- [ ] Run — expect GREEN. Commit.

## Task 3: Exact values outside the double range display as `Math ERROR`/`0`

**Files:** `lib/features/calculator/engine/number_format.dart:153-168`, harness

- [ ] Add `formatRationalDecimal(Rational, {int significant = 12})` to `number_format.dart`: exact scientific notation computed on `BigInt` (`10^400` → `1e400`, `1/10^400` → `1e-400`, `−3/2` → `−1.5`).
- [ ] Add checks: `formatCalcValue(EvalValue.exact(Rational.parse('1e400'))).decimal == '1e400'`; `formatCalcValue(EvalValue.exact(Rational.parse('1e-400')), preferExact: false).display == '1e-400'`; FIX 2 on `1e400` gives `1e400`, not `Math ERROR`.
- [ ] Run — expect RED (Math ERROR / 0).
- [ ] In `formatCalcValue`, when `exact != null` and `exact.toDouble()` is non-finite or 0 while the exact value is non-zero, use `formatRationalDecimal` for `decimal` (FIX does not round a value it cannot represent).
- [ ] Run — expect GREEN. Commit.

## Task 4: `rand()` returns the same value on every evaluation

**Files:** `lib/features/calculator/engine/evaluator.dart:48`, `lib/features/calculator/calc_session.dart`, harness

- [ ] Add checks: two `session.contextFor()` contexts share one `random` identity; 20 draws of `evaluate('rand(1000000)')` through a session produce at least two distinct values.
- [ ] Run — expect RED (all equal).
- [ ] Give `CalcSession` a `final math.Random random = math.Random()` (time-seeded) and pass it into `EvalContext` from `contextFor`.
- [ ] Run — expect GREEN. Commit.

## Task 5: `_stabilize` zeroes legitimate tiny results but keeps complex residue

**Files:** `lib/features/calculator/engine/evaluator.dart:902-911`, `engine/math_value.dart` (complex snapping), harness

- [ ] Add checks: `evaluate('exp(-30)').displayValue == evaluate('e^(-30)').displayValue`; `evaluate('1/exp(-30)')` is finite; CMPLX `(-1)^0.5` displays `i`, not `6.12e-17 + i`.
- [ ] Run — expect RED.
- [ ] Make the small-value zeroing relative for transcendental results (keep the absolute floor only for trig noise), and snap both real and imaginary parts with the same rule in the complex path.
- [ ] Run — expect GREEN; full harness green. Commit.

## Task 6: An unbounded literal exponent can freeze or OOM the app

**Files:** `lib/features/calculator/engine/math_value.dart:49-78`, harness

- [ ] Add checks: `Rational.tryParse('1e999999999')` is null (or `Rational.parse` throws `FormatException`) and `Rational.tryParse('1e-999999999')` likewise; `Rational.parse('1e400')` still works.
- [ ] Run — expect RED (allocation or success).
- [ ] Cap `|exponent|` and `scale` at 10,000 in `Rational.parse` and throw `FormatException`, matching `Evaluator._maxExactExponent`.
- [ ] Run — expect GREEN. Commit.

## Task 7: `Ans` followed by a letter becomes a zero product

**Files:** `lib/features/calculator/engine/parser.dart:200-211`, harness

- [ ] Add checks: with `Ans = 25`, `evaluate('Anse').displayValue` equals `evaluate('Ans*e').displayValue`; `evaluate('Ansx')` equals `Ans*x`.
- [ ] Run — expect RED (0).
- [ ] In `_identifier`, split a multi-letter run whose lowercase starts with a reserved multi-character name (`ans`) by longest match, instead of splitting every run into single letters.
- [ ] Run — expect GREEN. Commit.

## Task 8: The haptics setting is ignored by every mode handler

**Files:** `lib/features/calculator/modes/computation_mode.dart`, `base_n_mode.dart`, `cas_mode.dart`, `ui/calc_widgets.dart`

- [ ] Remove the unconditional `HapticFeedback` calls from the mode handlers (the key widget already honours `session.settings.haptics`).
- [ ] `dart analyze` clean; commit.

## Task 9: STO variables are lost when the screen closes

**Files:** `lib/features/calculator/calc_pro_screen.dart:162-165,232-262`, harness

- [ ] Add harness checks for `CalcSession.encodeVariables`/`decodeVariables` round-trip (new static helpers beside `encodeValue`).
- [ ] Run — expect RED (missing).
- [ ] Persist the variables map under `calc_pro_variables` in `_persist`/`_restore`.
- [ ] Run — expect GREEN; analyze clean; commit.

## Task 10: Fraction/polar dialogs reject Arabic-Indic digits and fail silently

**Files:** `lib/features/calculator/modes/computation_mode.dart:734-737,814-816`

- [ ] Run the field text through `normalizeCalculatorInput` before parsing, and show an inline error instead of returning silently.
- [ ] `dart analyze` clean; commit.

## Task 11: Delete the two dead CalculatorScreen implementations

**Files:** delete `lib/features/calculator/calculator_screen.dart`, `lib/features/tools/calculator_screen.dart`, `lib/features/calculator/calc_engine.dart`, `lib/features/calculator/calc_dialogs.dart` (plus any private widgets only they import).

- [ ] Re-verify zero importers outside the deleted set (`grep -rn`), delete, `dart analyze`, harness green; commit.

## Task 12: The calculator harness never runs

**Files:** `.github/workflows/build-apk.yml`

- [ ] Add a step after `flutter test`: `dart run tool/verify_calculator_logic.dart` (CI has a full Flutter SDK, so plain `dart run` works there).
- [ ] Commit. Note in the final message that CI billing currently blocks every run.
