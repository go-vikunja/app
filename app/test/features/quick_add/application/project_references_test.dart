import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/quick_add/application/project_references.dart';

import '../../../helpers/sample_data.dart';

void main() {
  final lower = sampleProject(id: 1, title: 'Work', identifier: 'ab');
  final upper = sampleProject(id: 2, title: 'Work', identifier: 'AB');
  final home = sampleProject(id: 3, title: 'Home', identifier: 'HOME');
  final candidates = [lower, upper, home];

  test('identifiers that differ only in case (Vikunja 2.3): the exact one, '
      'every one for another case', () {
    expect(projectsNamed('ab', candidates), [lower]);
    expect(projectsNamed('AB', candidates), [upper]);
    expect(projectsNamed('Ab', candidates), [lower, upper]);
    expect(projectsNamed('home', candidates), [home]);
    expect(projectsNamed('work', candidates), [lower, upper]);
  });

  test('an identifier is judged among the known projects, then kept only '
      'among the candidates: never the case twin of one that is not', () {
    final readOnly = sampleProject(id: 4, title: 'Shared', identifier: 'cd');
    final own = sampleProject(id: 5, title: 'Own', identifier: 'CD');
    final known = [readOnly, own, home];

    expect(projectsNamed('cd', [own, home], known: known), isEmpty);
    expect(projectsNamed('CD', [own, home], known: known), [own]);
    expect(projectsNamed('Cd', [own, home], known: known), [own]);
    expect(projectsNamed('cd', [readOnly, own], known: known), [readOnly]);
    expect(projectsNamed('Shared', [own, home], known: known), isEmpty);
  });

  test('two projects of one title are told apart by their identifiers as '
      'they are', () {
    expect(projectReference(lower, candidates), 'ab');
    expect(projectReference(upper, candidates), 'AB');
    expect(projectReference(home, candidates), 'Home');
  });
}
