// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Tests multiple local wildcard variable declarations.

void main() {
  var _ = 1;
  int _ = 2;
  final _ = 3;

  var i = 2, _ = 2;
  i = i + 1;

  int _;
  final _;

  late int _;
  late int _ = 2;

  late final int _;
  late final int _ = 2;

  const int _ = 2;
}
