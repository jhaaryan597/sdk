// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/integration_tests.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DeleteContextTest);
  });
}

@reflectiveTest
class DeleteContextTest extends AbstractAnalysisServerIntegrationTest {
  Future<void> test_delete() async {
    var pathname = sourcePath('lib/main.dart');
    writeFile(pathname, '// dummy');
    await standardAnalysisSetup();
    await analysisFinished;

    var contextId = (await sendExecutionCreateContext(sourceDirectory.path)).id;

    var result = await sendExecutionMapUri(
      contextId,
      uri: 'package:test/main.dart',
    );
    expect(result.file, pathname);

    await sendExecutionDeleteContext(contextId);

    // After the delete, expect this to fail.
    try {
      result = await sendExecutionMapUri(
        contextId,
        uri: 'package:test/main.dart',
      );
      fail('expected exception after context delete');
    } on ServerErrorMessage catch (message) {
      expect(message.error['code'], 'INVALID_PARAMETER');
    }
  }
}
