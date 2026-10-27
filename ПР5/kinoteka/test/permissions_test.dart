import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/auth/password_rules.dart';
import 'package:kinoteka/auth/permissions.dart';

/// Логика разграничения прав: соответствие роли и доступности операции.
void main() {
  group('Права ролей', () {
    test('зритель только смотрит каталог и пользуется своей картой', () {
      expect(roleCan(Role.viewer, Permission.catalogRead), isTrue);
      expect(roleCan(Role.viewer, Permission.cardOwn), isTrue);
      expect(roleCan(Role.viewer, Permission.catalogEdit), isFalse);
      expect(roleCan(Role.viewer, Permission.viewersManage), isFalse);
      expect(roleCan(Role.viewer, Permission.recordsHardDelete), isFalse);
    });

    test('менеджер ведёт каталог, зрителей и кассу, но не удаляет навсегда', () {
      expect(roleCan(Role.manager, Permission.catalogEdit), isTrue);
      expect(roleCan(Role.manager, Permission.viewersManage), isTrue);
      expect(roleCan(Role.manager, Permission.visitsMark), isTrue);
      expect(roleCan(Role.manager, Permission.recordsHardDelete), isFalse);
      expect(roleCan(Role.manager, Permission.recordsRestore), isFalse);
      expect(roleCan(Role.manager, Permission.trashView), isFalse);
    });

    test('администратор управляет пользователями, корзиной и статистикой', () {
      for (final p in [
        Permission.usersManage,
        Permission.statsView,
        Permission.recordsRestore,
        Permission.recordsHardDelete,
        Permission.trashView,
      ]) {
        expect(roleCan(Role.admin, p), isTrue, reason: p.code);
      }
    });

    test('у каждой роли есть право, которого нет у остальных двух', () {
      for (final role in Role.values) {
        final others = Role.values.where((r) => r != role);
        final own = rolePermissions[role]!
            .where((p) => others.every((o) => !roleCan(o, p)))
            .toList();
        expect(own, isNotEmpty, reason: role.code);
      }
    });

    test('без роли (не вошёл) не разрешено ничего', () {
      for (final p in Permission.values) {
        expect(roleCan(null, p), isFalse);
      }
    });

    test('неизвестная роль с сервера не превращается в администратора', () {
      expect(Role.fromCode('superuser'), isNull);
      expect(Role.fromCode('admin'), Role.admin);
    });
  });

  group('Право для адреса', () {
    test('разделы ролей', () {
      expect(permissionForLocation('/my-card'), Permission.cardOwn);
      expect(permissionForLocation('/box-office'), Permission.visitsMark);
      expect(permissionForLocation('/admin/users'), Permission.usersManage);
      expect(permissionForLocation('/admin/stats'), Permission.statsView);
      expect(permissionForLocation('/viewers/3'), Permission.viewersManage);
    });

    test('каталог читается всеми, а формы требуют права на изменение', () {
      expect(permissionForLocation('/movies'), Permission.catalogRead);
      expect(permissionForLocation('/movies/7'), Permission.catalogRead);
      expect(permissionForLocation('/movies/new'), Permission.catalogEdit);
      expect(permissionForLocation('/genres/2/edit'), Permission.catalogEdit);
      expect(permissionForLocation('/'), isNull);
    });
  });

  group('Пароль при регистрации', () {
    test('слабые пароли отклоняются с перечнем требований', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('короткий'), contains('цифра'));
      expect(validatePassword('password1'), contains('специальный'));
      expect(validatePassword('pass#1'), contains('8 символов'));
    });

    test('пароль с цифрой и специальным символом длиной от 8 принимается', () {
      expect(validatePassword('Kino#2026'), isNull);
    });
  });
}
