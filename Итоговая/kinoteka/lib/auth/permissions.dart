/// Роли пользователей «Кинотеки». Роль приходит с сервера при входе
/// внутри ответа и подписанного токена доступа.
enum Role {
  viewer('viewer', 'Зритель'),
  manager('manager', 'Менеджер'),
  admin('admin', 'Администратор');

  const Role(this.code, this.title);

  final String code;
  final String title;

  static Role? fromCode(Object? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// Операции, доступ к которым различается по ролям. Имена совпадают
/// с таблицей permissions в базе (supabase/schema.sql).
enum Permission {
  catalogRead('catalog.read', 'просмотр каталога'),
  catalogEdit('catalog.edit', 'изменение фильмов и справочников'),
  viewersManage('viewers.manage', 'работа со зрителями'),
  visitsMark('visits.mark', 'отметка посещений (касса)'),
  cardOwn('card.own', 'своя карта и продление абонемента'),
  trashView('trash.view', 'просмотр корзины'),
  recordsRestore('records.restore', 'восстановление записей'),
  recordsHardDelete('records.hardDelete', 'удаление навсегда'),
  usersManage('users.manage', 'управление пользователями и ролями'),
  statsView('stats.view', 'статистика');

  const Permission(this.code, this.title);

  final String code;
  final String title;
}

/// Права ролей в разрезе операций.
///
/// Наборы различаются составом, а не объёмом: у зрителя есть своя карта,
/// которой нет у остальных, у менеджера — касса, у администратора —
/// пользователи, корзина и статистика.
///
/// На клиенте таблица только решает, какие кнопки и разделы показать.
/// Разрешение на операцию даёт сервер — по роли из подписанного токена.
const rolePermissions = <Role, Set<Permission>>{
  Role.viewer: {Permission.catalogRead, Permission.cardOwn},
  Role.manager: {Permission.catalogRead, Permission.catalogEdit, Permission.viewersManage, Permission.visitsMark},
  Role.admin: {
    Permission.catalogRead,
    Permission.catalogEdit,
    Permission.viewersManage,
    Permission.trashView,
    Permission.recordsRestore,
    Permission.recordsHardDelete,
    Permission.usersManage,
    Permission.statsView,
  },
};

bool roleCan(Role? role, Permission permission) =>
    role != null && (rolePermissions[role]?.contains(permission) ?? false);

/// Какое право нужно для адреса приложения. null — достаточно войти.
Permission? permissionForLocation(String path) {
  bool under(String prefix) => path == prefix || path.startsWith('$prefix/');

  if (under('/my-card')) return Permission.cardOwn;
  if (under('/box-office')) return Permission.visitsMark;
  if (under('/admin/users')) return Permission.usersManage;
  if (under('/admin/stats')) return Permission.statsView;
  if (under('/viewers')) return Permission.viewersManage;
  for (final p in const ['/movies', '/directors', '/genres', '/studios']) {
    if (path == '$p/new' || (path.startsWith('$p/') && path.endsWith('/edit'))) {
      return Permission.catalogEdit;
    }
    if (under(p)) return Permission.catalogRead;
  }
  return null;
}
