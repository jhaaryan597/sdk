// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Shared code used by cfe_perf and incremental_perf.
library front_end.tool.perf_common;

import 'dart:io' show exitCode, stderr;

import 'package:_fe_analyzer_shared/src/messages/diagnostic_message.dart'
    show DiagnosticMessage, DiagnosticMessageHandler, getMessageCodeObject;
import 'package:_fe_analyzer_shared/src/messages/severity.dart' show Severity;
import 'package:front_end/src/api_prototype/terminal_color_support.dart'
    show printDiagnosticMessage;
import 'package:front_end/src/codes/cfe_codes.dart' as cfeCodes;
import 'package:kernel/target/targets.dart' show Target, TargetFlags;
import 'package:vm/modular/target/flutter.dart' show FlutterTarget;
import 'package:vm/modular/target/vm.dart' show VmTarget;

/// Error messages that we temporarily allow when compiling benchmarks in strong
/// mode.
///
/// This allowlist lets us run the compiler benchmarks while those errors get
/// fixed. We don't blindly allow any error message because we would then miss
/// situations where the benchmarks are actually broken.
///
/// Note: the performance bots compile both dart2js and the flutter-gallery app
/// as benchmarks, so they both need to be checked before we remove a message
/// from this set.
final allowlistMessageCode = new Set<cfeCodes.Code>.from(<cfeCodes.Code>[
  // Code names in this list should match the key used in messages.yaml
  cfeCodes.codeInvalidAssignmentError,
  cfeCodes.codeOverrideTypeMismatchParameter,
  cfeCodes.codeOverriddenMethodCause,

  // The following errors are not covered by unit tests in the SDK repo because
  // they are only seen today in the flutter-gallery benchmark (external to
  // this repo).
  cfeCodes.codeInvalidCastFunctionExpr,
  cfeCodes.codeInvalidCastTopLevelFunction,
  cfeCodes.codeUndefinedGetter,
  cfeCodes.codeUndefinedMethod,
]);

DiagnosticMessageHandler onDiagnosticMessageHandler() {
  bool messageReported = false;
  return (DiagnosticMessage m) {
    if (m.severity == Severity.internalProblem ||
        m.severity == Severity.error) {
      if (!allowlistMessageCode.contains(getMessageCodeObject(m))) {
        printDiagnosticMessage(m, stderr.writeln);
        exitCode = 1;
      } else if (!messageReported) {
        messageReported = true;
        stderr.writeln('Allowlisted error messages omitted');
      }
    }
  };
}

/// Creates a [VmTarget] or [FlutterTarget] with legacy mode enabled or
/// disabled.
// TODO(sigmund): delete as soon as the disableTypeInference flag and the
// legacyMode flag get merged, and we have a single way of specifying the
// legacy-mode flag to the FE.
Target createTarget({bool isFlutter = false}) {
  TargetFlags flags = new TargetFlags();
  if (isFlutter) {
    return new FlutterTarget(flags);
  } else {
    return new VmTarget(flags);
  }
}

class TimingsCollector {
  final Stopwatch stopwatch = new Stopwatch();

  final Map<String, List<double>> timings = <String, List<double>>{};

  final bool verbose;

  TimingsCollector(this.verbose);

  String? currentKey;

  void start(String key) {
    if (currentKey != null) {
      throw "Attempt to time '$key' while '$currentKey' is running.";
    }
    currentKey = key;
    stopwatch
      ..reset()
      ..start();
  }

  void stop(String key) {
    stopwatch.stop();
    if (currentKey == null) {
      throw "Need to call 'start' before calling 'stop'.";
    }
    if (currentKey != key) {
      throw "Can't stop timing '$key' because '$currentKey' is running.";
    }
    currentKey = null;
    double duration =
        stopwatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond;
    List<double> durations = (timings[key] ??= <double>[]);
    durations.add(duration);
    if (verbose) {
      print("$key took: ${duration}ms");
    }
  }

  void printTimings() {
    timings.forEach((String key, List<double> durations) {
      double total = 0.0;
      int length = durations.length;
      if (length == 1) {
        total += durations.single;
      } else {
        length -= 3;
        for (double duration in durations.skip(3)) {
          total += duration;
        }
      }
      print("$key took: ${total / length}ms");
    });
  }
}
