import 'package:flutter_test/flutter_test.dart';
import 'package:trailguard_ai/models/user_profile.dart';
import 'package:trailguard_ai/services/survival_kb.dart';

void main() {
  String? ask(String q, {UserProfile? p}) =>
      SurvivalKnowledgeBase.answer(q, profile: p);

  group('topic matching', () {
    test('matches the obvious phrasing', () {
      expect(ask('how do I purify water from a stream?'), contains('Water'));
      expect(ask('I think I am lost'), contains('Lost'));
      expect(ask('how do I light a fire in the rain'), contains('Fire'));
    });

    test('matches natural phrasing, not just keywords', () {
      expect(ask('my friend was bitten by a snake'), contains('Snake bite'));
      expect(ask('there is a thunderstorm coming'), contains('Lightning'));
      expect(ask('can I eat these berries'), contains('Eating wild food'));
    });

    test('life-threatening topics outrank general ones', () {
      // Mentions both bleeding and being lost — bleeding must win.
      final a = ask('I am lost and my leg is bleeding badly')!;
      expect(a, contains('Severe bleeding'));
      expect(a, isNot(contains('S — Stop and sit down')));
    });

    test('returns null when nothing fits, rather than a bad guess', () {
      expect(ask('what is the capital of France'), isNull);
      expect(ask('write me a poem'), isNull);
    });
  });

  group('answer quality', () {
    test('gives actionable steps, not a refusal', () {
      final a = ask('how do I purify water')!;
      expect(a, contains('Boil'));
      expect(a, isNot(contains('model')));
      expect(a.length, greaterThan(200));
    });

    test('snake bite includes the things people get wrong', () {
      final a = ask('snake bite')!.toLowerCase();
      expect(a, contains('do not cut'));
      expect(a, contains('tourniquet'));
    });
  });

  group('profile personalisation', () {
    final p = UserProfile(
      name: 'Sam Okafor',
      bloodGroup: 'O-',
      allergies: 'penicillin',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('greets by first name only', () {
      expect(ask('water', p: p), startsWith('Sam — '));
    });

    test('attaches medical facts to medical topics', () {
      final a = ask('severe bleeding', p: p)!;
      expect(a, contains('O-'));
      expect(a, contains('penicillin'));
    });

    test('does not attach medical facts to fieldcraft topics', () {
      final a = ask('how do I light a fire', p: p)!;
      expect(a, isNot(contains('O-')));
      expect(a, isNot(contains('penicillin')));
    });

    test('an empty profile adds nothing', () {
      final a = ask('water', p: UserProfile(
          name: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1)))!;
      expect(a, startsWith('**Water**'));
    });
  });

  test('the fallback names what it can actually answer', () {
    final f = SurvivalKnowledgeBase.notFound();
    expect(f, contains('water'));
    expect(f, contains('snake bite'));
  });

  test('every starter question resolves to a real answer', () {
    for (final s in SurvivalKnowledgeBase.starters) {
      expect(ask(s.question), isNotNull,
          reason: 'starter question had no answer: "${s.question}"');
      expect(ask(s.label), isNotNull,
          reason: 'starter label had no answer: "${s.label}"');
    }
  });
}
