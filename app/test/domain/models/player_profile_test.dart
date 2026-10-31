import 'package:flutter_test/flutter_test.dart';
import 'package:leva/domain/models/player_profile.dart';

const julia = PlayerProfile(
  uid: 'u1',
  displayName: 'Julia Gasparini',
  nickname: 'Juli',
  category: PlayerCategory.cuarta,
  club: 'Pádel Providencia',
  hand: Hand.diestra,
  position: CourtPosition.reves,
);

void main() {
  test('iniciales, nombre y apellido', () {
    expect(julia.initials, 'JG');
    expect(julia.firstName, 'Julia');
    expect(julia.lastName, 'Gasparini');
    expect(julia.copyWith(displayName: 'César de Anda').initials, 'CA');
    expect(julia.copyWith(displayName: '  Marvin  ').initials, 'M');
  });

  test('editableJson solo trae campos editables y limpia espacios', () {
    final json = julia
        .copyWith(displayName: '  Julia Gasparini ', nickname: '   ')
        .editableJson();
    expect(
      json.keys,
      unorderedEquals([
        'displayName',
        'nickname',
        'category',
        'club',
        'hand',
        'position',
        'photoUrl',
      ]),
    );
    expect(json['displayName'], 'Julia Gasparini');
    expect(
      json['nickname'],
      isNull,
      reason: 'un apodo en blanco se guarda como null',
    );
    expect(json['category'], 'cuarta');
    expect(json.containsKey('rankingPoints'), isFalse);
  });

  test('ida y vuelta con lo que guarda Firestore', () {
    final stored = {
      ...julia.editableJson(),
      'rankingPoints': 120,
      'stats': {'tournaments': 7, 'titles': 1},
      'ambassador': true,
    };
    final back = PlayerProfile.fromJson('u1', stored);
    expect(back.displayName, julia.displayName);
    expect(back.category, PlayerCategory.cuarta);
    expect(back.position, CourtPosition.reves);
    expect(back.tournaments, 7);
    expect(back.titles, 1);
    expect(back.ambassador, isTrue);
  });

  test('valores desconocidos no rompen la lectura', () {
    final p = PlayerProfile.fromJson('x', {
      'displayName': 'Ana Ruiz',
      'category': '7ma',
      'hand': '?',
    });
    expect(p.category, PlayerCategory.sexta);
    expect(p.hand, Hand.diestra);
  });

  group('validaciones con mensaje en español', () {
    test('nombre', () {
      expect(ProfileValidators.displayName(''), 'Escribe tu nombre.');
      expect(ProfileValidators.displayName('Jo'), 'Tu nombre es muy corto.');
      expect(
        ProfileValidators.displayName('Marvin'),
        'Escribe nombre y apellido.',
      );
      expect(ProfileValidators.displayName('Julia Gasparini'), isNull);
      expect(
        ProfileValidators.displayName('a b${'c' * 40}'),
        'Máximo 40 caracteres.',
      );
    });

    test('apodo y club', () {
      expect(ProfileValidators.nickname(null), isNull);
      expect(ProfileValidators.nickname('x' * 21), isNotNull);
      expect(ProfileValidators.club(' '), contains('Sin club'));
      expect(ProfileValidators.club('Zapopan Pádel'), isNull);
    });
  });

  group('búsqueda de jugadores', () {
    const cesar = PlayerProfile(
      uid: 'c',
      displayName: 'César de Anda',
      nickname: 'Chispita',
      category: PlayerCategory.cuarta,
      club: 'Zapopan',
      hand: Hand.diestra,
      position: CourtPosition.drive,
    );

    test('sin acentos ni mayúsculas', () {
      expect(normalizeForSearch('  César DE Ánda '), 'cesar de anda');
      expect(matchesPlayerQuery(cesar, 'cesar'), isTrue);
      expect(matchesPlayerQuery(cesar, 'CÉSAR'), isTrue);
    });

    test('por apellido, apodo o varias palabras', () {
      expect(matchesPlayerQuery(cesar, 'anda'), isTrue);
      expect(matchesPlayerQuery(cesar, 'chispi'), isTrue);
      expect(matchesPlayerQuery(cesar, 'ces de an'), isTrue);
    });

    test('no coincide a mitad de palabra ni con vacío', () {
      expect(matchesPlayerQuery(cesar, 'sar'), isFalse);
      expect(matchesPlayerQuery(cesar, 'julia'), isFalse);
      expect(matchesPlayerQuery(cesar, '   '), isFalse);
    });
  });
}
