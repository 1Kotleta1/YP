import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/auth/permissions.dart';
import 'package:kinoteka/core/api_exceptions.dart';
import 'package:kinoteka/core/server_status.dart';
import 'package:kinoteka/models/genre.dart';
import 'package:kinoteka/models/simple_query.dart';

import 'helpers/test_app.dart';

void main() {
  group('Состояния списка', () {
    testWidgets('пока сервер не ответил, виден индикатор загрузки', (tester) async {
      final genres = FakeRepository<Genre, SimpleQuery>([drama])..gate = Completer();
      final app = await TestApp.create(tester, role: Role.manager, genres: genres);

      await tester.pumpWidget(app.widget);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Загрузка…'), findsOneWidget);
      expect(find.text('Драма'), findsNothing);

      genres.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Драма'), findsOneWidget);
      await app.close(tester);
    });

    testWidgets('пустой результат — сообщение, а не пустой экран', (tester) async {
      final app = await TestApp.create(tester, role: Role.manager, genres: FakeRepository([]));

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await app.close(tester);
    });

    testWidgets('ошибка — сообщение и кнопка «Повторить», которая загружает заново', (tester) async {
      final genres = FakeRepository<Genre, SimpleQuery>([drama])..error = const NetworkException();
      final app = await TestApp.create(tester, role: Role.manager, genres: genres);

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      expect(find.text('Ошибка загрузки'), findsOneWidget);
      expect(find.textContaining('Сервер недоступен'), findsOneWidget);
      final calls = genres.findCalls;

      // Связь вернулась — повтор показывает данные
      genres.error = null;
      await tester.tap(find.widgetWithText(FilledButton, 'Повторить'));
      await tester.pumpAndSettle();

      expect(genres.findCalls, calls + 1);
      expect(find.text('Ошибка загрузки'), findsNothing);
      expect(find.text('Драма'), findsOneWidget);
      await app.close(tester);
    });
  });

  group('Форма', () {
    testWidgets('пустая форма не отправляется, под полями — подсказки', (tester) async {
      final app = await TestApp.create(tester, role: Role.manager, location: '/genres/new');

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();
      expect(find.text('Новый жанр'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
      await tester.pumpAndSettle();

      expect(find.text('Обязательное поле'), findsOneWidget);
      expect(find.text('Выберите категорию'), findsOneWidget);
      expect(app.genres.created, isEmpty);
      await app.close(tester);
    });

    testWidgets('заполненная форма сохраняет запись', (tester) async {
      final app = await TestApp.create(tester, role: Role.manager, location: '/genres/new');

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Название'), 'Вестерн');
      await tester.tap(find.text('Категория'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Игровое кино').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
      await tester.pumpAndSettle();

      expect(app.genres.created.single.name, 'Вестерн');
      await app.close(tester);
    });
  });

  group('Роли', () {
    testWidgets('зрителю не видны кнопка добавления и раздел «Зрители»', (tester) async {
      final app = await TestApp.create(tester, role: Role.viewer);

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      expect(find.text('Драма'), findsOneWidget);
      expect(find.text('Новый жанр'), findsNothing);
      expect(find.text('Зрители'), findsNothing);
      expect(find.text('Моя карта'), findsOneWidget);
      await app.close(tester);
    });

    testWidgets('менеджеру те же элементы доступны', (tester) async {
      final app = await TestApp.create(tester, role: Role.manager);

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      expect(find.text('Новый жанр'), findsOneWidget);
      expect(find.text('Зрители'), findsOneWidget);
      expect(find.text('Моя карта'), findsNothing);
      await app.close(tester);
    });

    testWidgets('прямой адрес формы при недостаточной роли ведёт на экран отказа', (tester) async {
      final app = await TestApp.create(tester, role: Role.viewer, location: '/genres/new');

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      expect(find.text('Недостаточно прав'), findsOneWidget);
      expect(find.text('Создать'), findsNothing);
      await app.close(tester);
    });
  });

  group('Адаптивная раскладка', () {
    testWidgets('на узком окне — карточки и нижняя навигация', (tester) async {
      final app = await TestApp.create(tester, role: Role.manager, size: const Size(360, 780));

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsWidgets);
      expect(tester.takeException(), isNull);
      await app.close(tester);
    });

    testWidgets('на окне 1280 — таблица и боковая навигация с подписями', (tester) async {
      final app = await TestApp.create(tester, role: Role.manager);

      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isTrue);
      await app.close(tester);
    });
  });

  group('Связь с сервером', () {
    test('после сбоя сервер опрашивается, и слушатели узнают о восстановлении', () async {
      var up = false;
      final status = ServerStatus(() async => up, interval: const Duration(hours: 1));
      var notified = 0;
      status.addListener(() => notified++);

      status.reportFailure();
      expect(status.online, isFalse);

      await status.check();
      expect(status.online, isFalse);

      up = true;
      await status.check();
      expect(status.online, isTrue);
      expect(notified, 2);
      status.dispose();
    });
  });
}
