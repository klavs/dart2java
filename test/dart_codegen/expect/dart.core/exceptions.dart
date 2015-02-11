part of dart.core;

abstract class Exception {
  factory Exception([var message]) => new _ExceptionImplementation(message);
}
class _ExceptionImplementation implements Exception {
  final message;
  _ExceptionImplementation([this.message]);
  String toString() {
    if (message == null) return "Exception";
    return "Exception: $message";
  }
}
class FormatException implements Exception {
  final String message;
  final source;
  final int offset;
  const FormatException([this.message = "", this.source, this.offset]);
  String toString() {
    String report = "FormatException";
    if (message != null && "" != message) {
      report = "$report: $message";
    }
    int offset = this.offset;
    if (source is! String) {
      if (offset != null) {
        report += " (at offset $offset)";
      }
      return report;
    }
    if (offset != null && (offset < 0 || offset > source.length)) {
      offset = null;
    }
    if (offset == null) {
      String source = ((__x3) => DDC$RT.cast(__x3, dynamic, String,
          "CastGeneral",
          """line 113, column 23 of dart:core/exceptions.dart: """,
          __x3 is String, true))(this.source);
      if (source.length > 78) {
        source = source.substring(0, 75) + "...";
      }
      return "$report\n$source";
    }
    int lineNum = 1;
    int lineStart = 0;
    bool lastWasCR;
    for (int i = 0; i < offset; i++) {
      int char = ((__x4) => DDC$RT.cast(__x4, dynamic, int, "CastGeneral",
          """line 123, column 18 of dart:core/exceptions.dart: """, __x4 is int,
          true))(source.codeUnitAt(i));
      if (char == 0x0a) {
        if (lineStart != i || !lastWasCR) {
          lineNum++;
        }
        lineStart = i + 1;
        lastWasCR = false;
      } else if (char == 0x0d) {
        lineNum++;
        lineStart = i + 1;
        lastWasCR = true;
      }
    }
    if (lineNum > 1) {
      report += " (at line $lineNum, character ${offset - lineStart + 1})\n";
    } else {
      report += " (at character ${offset + 1})\n";
    }
    int lineEnd = DDC$RT.cast(source.length, dynamic, int, "CastGeneral",
        """line 141, column 19 of dart:core/exceptions.dart: """,
        source.length is int, true);
    for (int i = offset; i < source.length; i++) {
      int char = ((__x5) => DDC$RT.cast(__x5, dynamic, int, "CastGeneral",
          """line 143, column 18 of dart:core/exceptions.dart: """, __x5 is int,
          true))(source.codeUnitAt(i));
      if (char == 0x0a || char == 0x0d) {
        lineEnd = i;
        break;
      }
    }
    int length = lineEnd - lineStart;
    int start = lineStart;
    int end = lineEnd;
    String prefix = "";
    String postfix = "";
    if (length > 78) {
      int index = offset - lineStart;
      if (index < 75) {
        end = start + 75;
        postfix = "...";
      } else if (end - offset < 75) {
        start = end - 75;
        prefix = "...";
      } else {
        start = offset - 36;
        end = offset + 36;
        prefix = postfix = "...";
      }
    }
    String slice = ((__x6) => DDC$RT.cast(__x6, dynamic, String, "CastGeneral",
        """line 171, column 20 of dart:core/exceptions.dart: """,
        __x6 is String, true))(source.substring(start, end));
    int markOffset = offset - start + prefix.length;
    return "$report$prefix$slice$postfix\n${" " * markOffset}^\n";
  }
}
class IntegerDivisionByZeroException implements Exception {
  const IntegerDivisionByZeroException();
  String toString() => "IntegerDivisionByZeroException";
}