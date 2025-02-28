// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:front_end/src/api_unstable/vm.dart' show FileSystem;
import 'package:kernel/ast.dart';
import 'package:kernel/util/graph.dart';

/// Compute the strongly connected components for JavaScript compilation.
///
/// Implements a Path-based strong component algorithm.
/// See https://en.wikipedia.org/wiki/Path-based_strong_component_algorithm
///
/// The file URI for each library is used as an identifier for the library
/// bundle name. [libraryImportToLibraryBundleImport] will be populated with a
/// mapping of library URI to library bundle name, while
/// [libraryBundleImportToLibraries] will be populated with a mapping of library
/// bundle name to library set.
///
/// JavaScript import semantics do not permit circular imports in the same
/// manner that Dart does. When compiling a set of libraries with circular
/// imports, these must be combined into a single JavaScript library bundle.
///
/// On incremental updates, we completely recompute the strongly connected
/// components, but only for the partial component produced.
class StrongComponents {
  StrongComponents(
    this.component,
    this.loadedLibraries,
    this.mainUri, [
    this.fileSystem,
  ]);

  /// The Component that is being compiled.
  ///
  /// On incremental compiles, this will only contain the invalidated
  /// libraries.
  final Component component;

  /// The libraries loaded from a dill file that should not be processed.
  final Set<Library> loadedLibraries;

  /// The main URI for this application.
  final Uri mainUri;

  /// The filesystem instance for resolving files.
  final FileSystem? fileSystem;

  /// Libraries for each library bundle URI.
  ///
  /// This is populated after calling [computeLibraryBundles] once.
  final Map<Uri, List<Library>> libraryBundleImportToLibraries =
      <Uri, List<Library>>{};

  /// The library bundle URI for each library URI.
  ///
  /// This is populated after calling [computeLibraryBundles] once.
  final Map<Uri, Uri> libraryImportToLibraryBundleImport = <Uri, Uri>{};

  /// Compute the strongly connected components for the current program.
  ///
  /// Allows providing a set of libraries to replace what is defined in the
  /// component via [partialComponent]. When traversing the import graph,
  /// instead of loading the library defined in a [LibraryDependency], if
  /// present the library in the partial component will replace it.
  ///
  /// Throws an [Exception] if [mainUri] cannot be located in the given
  /// component.
  Future<void> computeLibraryBundles(
      [Map<Uri, Library>? partialComponent]) async {
    assert(libraryBundleImportToLibraries.isEmpty);
    if (component.libraries.isEmpty) {
      return;
    }
    Library? entrypoint;
    for (Library library in component.libraries) {
      if (library.fileUri == mainUri || library.importUri == mainUri) {
        entrypoint = library;
        break;
      }
    }

    if (entrypoint == null) {
      throw new Exception('Could not find entrypoint $mainUri in Component.');
    }

    final List<List<Library>> results = computeStrongComponents(
        new _LibraryGraph(entrypoint, loadedLibraries, partialComponent));
    for (List<Library> component in results) {
      assert(component.isNotEmpty);
      // Pick a Uri to associate this component with. We choose the entrypoint
      // if it exists or just the first library's Uri.
      final Uri componentUri = component
          .firstWhere((lib) => lib.importUri == mainUri,
              orElse: () => component.first)
          .importUri;
      libraryBundleImportToLibraries[componentUri] = component;
      for (Library componentLibrary in component) {
        libraryImportToLibraryBundleImport[componentLibrary.importUri] =
            componentUri;
      }
    }
  }
}

class _LibraryGraph implements Graph<Library> {
  _LibraryGraph(this.library, this.loadedLibraries, [this._partialComponent]);

  final Library library;
  final Set<Library> loadedLibraries;
  final Map<Uri, Library>? _partialComponent;

  @override
  Iterable<Library> neighborsOf(Library vertex) {
    return <Library>[
      for (LibraryDependency dependency in vertex.dependencies)
        if (!loadedLibraries.contains(dependency.targetLibrary) &&
            !dependency.targetLibrary.importUri.isScheme('dart'))
          _partialComponent == null
              ? dependency.targetLibrary
              : _partialComponent[dependency.targetLibrary.importUri] ??
                  dependency.targetLibrary
    ];
  }

  @override
  Iterable<Library> get vertices => <Library>[library];
}
