import '../models/director.dart';
import '../models/movie.dart';
import '../models/genre.dart';
import '../models/studio.dart';
import '../models/viewer.dart';

/// Начальный набор данных. Записывается в хранилище при первом запуске;
/// дальше изменения пользователя переживают перезагрузку страницы.

const seedGenres = <Genre>[
  Genre(id: 1, name: 'Драма', category: 'Игровое кино', description: 'Серьёзные истории о людях и отношениях'),
  Genre(id: 2, name: 'Фантастика', category: 'Игровое кино', description: 'Будущее, космос и технологии'),
  Genre(id: 3, name: 'Триллер', category: 'Игровое кино', description: 'Напряжение и неожиданные повороты'),
  Genre(id: 4, name: 'Комедия', category: 'Игровое кино', description: 'Лёгкие и смешные истории'),
  Genre(id: 5, name: 'Анимация', category: 'Анимация', description: 'Рисованные и кукольные фильмы'),
  Genre(id: 6, name: 'Криминал', category: 'Игровое кино', description: 'Истории о преступлениях'),
  Genre(id: 7, name: 'Приключения', category: 'Игровое кино', description: 'Путешествия и поиски'),
  Genre(id: 8, name: 'Боевик', category: 'Игровое кино', description: 'Погони, драки и спецэффекты'),
  Genre(id: 9, name: 'Детектив', category: 'Игровое кино', description: 'Расследования и загадки'),
  Genre(id: 10, name: 'Мелодрама', category: 'Игровое кино', description: 'Истории о любви'),
];

const seedStudios = <Studio>[
  Studio(id: 1, name: 'Warner Bros.', country: 'США', foundedYear: 1923),
  Studio(id: 2, name: 'Universal Pictures', country: 'США', foundedYear: 1912),
  Studio(id: 3, name: 'Мосфильм', country: 'Россия', foundedYear: 1923),
  Studio(id: 4, name: 'Studio Ghibli', country: 'Япония', foundedYear: 1985),
  Studio(id: 5, name: 'Paramount Pictures', country: 'США', foundedYear: 1912),
  Studio(id: 6, name: '20th Century Studios', country: 'США', foundedYear: 1935),
  Studio(id: 7, name: 'Legendary Pictures', country: 'США', foundedYear: 2000),
  Studio(id: 8, name: 'Non-Stop Production', country: 'Россия', foundedYear: 1992),
  Studio(id: 9, name: 'CJ Entertainment', country: 'Южная Корея', foundedYear: 1995),
  Studio(id: 10, name: 'Miramax', country: 'США', foundedYear: 1979),
  Studio(id: 11, name: 'СТВ', country: 'Россия', foundedYear: 1992),
  Studio(id: 12, name: 'Columbia Pictures', country: 'США', foundedYear: 1918),
];

const seedDirectors = <Director>[
  Director(id: 1, lastName: 'Нолан', firstName: 'Кристофер', country: 'Великобритания', birthYear: 1970),
  Director(id: 2, lastName: 'Тарковский', firstName: 'Андрей', country: 'Россия', birthYear: 1932),
  Director(id: 3, lastName: 'Спилберг', firstName: 'Стивен', country: 'США', birthYear: 1946),
  Director(id: 4, lastName: 'Миядзаки', firstName: 'Хаяо', country: 'Япония', birthYear: 1941),
  Director(id: 5, lastName: 'Скорсезе', firstName: 'Мартин', country: 'США', birthYear: 1942),
  Director(id: 6, lastName: 'Финчер', firstName: 'Дэвид', country: 'США', birthYear: 1962),
  Director(id: 7, lastName: 'Вильнёв', firstName: 'Дени', country: 'Канада', birthYear: 1967),
  Director(id: 8, lastName: 'Звягинцев', firstName: 'Андрей', country: 'Россия', birthYear: 1964),
  Director(id: 9, lastName: 'Тарантино', firstName: 'Квентин', country: 'США', birthYear: 1963),
  Director(id: 10, lastName: 'Пон', firstName: 'Джун-хо', country: 'Южная Корея', birthYear: 1969),
  Director(id: 11, lastName: 'Балабанов', firstName: 'Алексей', country: 'Россия', birthYear: 1959),
  Director(id: 12, lastName: 'Кэмерон', firstName: 'Джеймс', country: 'Канада', birthYear: 1954),
  Director(id: 13, lastName: 'Рязанов', firstName: 'Эльдар', country: 'Россия', birthYear: 1927),
  Director(id: 14, lastName: 'Данелия', firstName: 'Георгий', country: 'Россия', birthYear: 1930),
];

const seedMovies = <Movie>[
  Movie(id: 1, title: 'Начало', originalTitle: 'Inception', year: 2010, duration: 148, rating: 8.7, licenseNumber: '121000001', studioId: 1, directorIds: [1], genreIds: [2, 8, 3]),
  Movie(id: 2, title: 'Интерстеллар', originalTitle: 'Interstellar', year: 2014, duration: 169, rating: 8.6, licenseNumber: '121000002', studioId: 5, directorIds: [1], genreIds: [2, 1, 7]),
  Movie(id: 3, title: 'Тёмный рыцарь', originalTitle: 'The Dark Knight', year: 2008, duration: 152, rating: 8.5, licenseNumber: '121000003', studioId: 1, directorIds: [1], genreIds: [8, 6, 1]),
  Movie(id: 4, title: 'Престиж', originalTitle: 'The Prestige', year: 2006, duration: 130, rating: 8.5, licenseNumber: '121000004', studioId: 1, directorIds: [1], genreIds: [1, 3, 9]),
  Movie(id: 5, title: 'Оппенгеймер', originalTitle: 'Oppenheimer', year: 2023, duration: 180, rating: 8.1, licenseNumber: '121000005', studioId: 2, directorIds: [1], genreIds: [1]),
  Movie(id: 6, title: 'Солярис', originalTitle: 'Солярис', year: 1972, duration: 167, rating: 7.7, licenseNumber: '121000006', studioId: 3, directorIds: [2], genreIds: [2, 1]),
  Movie(id: 7, title: 'Сталкер', originalTitle: 'Сталкер', year: 1979, duration: 163, rating: 8.1, licenseNumber: '121000007', studioId: 3, directorIds: [2], genreIds: [2, 1]),
  Movie(id: 8, title: 'Зеркало', originalTitle: 'Зеркало', year: 1974, duration: 107, rating: 7.9, licenseNumber: '121000008', studioId: 3, directorIds: [2], genreIds: [1]),
  Movie(id: 9, title: 'Список Шиндлера', originalTitle: "Schindler's List", year: 1993, duration: 195, rating: 8.8, licenseNumber: '121000009', studioId: 2, directorIds: [3], genreIds: [1]),
  Movie(id: 10, title: 'Парк юрского периода', originalTitle: 'Jurassic Park', year: 1993, duration: 127, rating: 8.0, licenseNumber: '121000010', studioId: 2, directorIds: [3], genreIds: [2, 7]),
  Movie(id: 11, title: 'Спасти рядового Райана', originalTitle: 'Saving Private Ryan', year: 1998, duration: 169, rating: 8.3, licenseNumber: '121000011', studioId: 5, directorIds: [3], genreIds: [1, 8]),
  Movie(id: 12, title: 'Унесённые призраками', originalTitle: 'Sen to Chihiro no Kamikakushi', year: 2001, duration: 125, rating: 8.5, licenseNumber: '121000012', studioId: 4, directorIds: [4], genreIds: [5, 7]),
  Movie(id: 13, title: 'Мой сосед Тоторо', originalTitle: 'Tonari no Totoro', year: 1988, duration: 86, rating: 8.3, licenseNumber: '121000013', studioId: 4, directorIds: [4], genreIds: [5, 4]),
  Movie(id: 14, title: 'Ходячий замок', originalTitle: 'Hauru no Ugoku Shiro', year: 2004, duration: 119, rating: 8.3, licenseNumber: '121000014', studioId: 4, directorIds: [4], genreIds: [5, 7, 10]),
  Movie(id: 15, title: 'Отступники', originalTitle: 'The Departed', year: 2006, duration: 151, rating: 8.5, licenseNumber: '121000015', studioId: 1, directorIds: [5], genreIds: [6, 3]),
  Movie(id: 16, title: 'Остров проклятых', originalTitle: 'Shutter Island', year: 2010, duration: 138, rating: 8.5, licenseNumber: '121000016', studioId: 5, directorIds: [5], genreIds: [3, 9]),
  Movie(id: 17, title: 'Волк с Уолл-стрит', originalTitle: 'The Wolf of Wall Street', year: 2013, duration: 180, rating: 8.0, licenseNumber: '121000017', studioId: 5, directorIds: [5], genreIds: [4, 6]),
  Movie(id: 18, title: 'Бойцовский клуб', originalTitle: 'Fight Club', year: 1999, duration: 139, rating: 8.7, licenseNumber: '121000018', studioId: 6, directorIds: [6], genreIds: [1, 3]),
  Movie(id: 19, title: 'Семь', originalTitle: 'Se7en', year: 1995, duration: 127, rating: 8.3, licenseNumber: '121000019', studioId: 1, directorIds: [6], genreIds: [3, 6, 9]),
  Movie(id: 20, title: 'Исчезнувшая', originalTitle: 'Gone Girl', year: 2014, duration: 149, rating: 8.0, licenseNumber: '121000020', studioId: 6, directorIds: [6], genreIds: [3, 9]),
  Movie(id: 21, title: 'Прибытие', originalTitle: 'Arrival', year: 2016, duration: 116, rating: 7.7, licenseNumber: '121000021', studioId: 5, directorIds: [7], genreIds: [2, 1]),
  Movie(id: 22, title: 'Бегущий по лезвию 2049', originalTitle: 'Blade Runner 2049', year: 2017, duration: 163, rating: 7.9, licenseNumber: '121000022', studioId: 1, directorIds: [7], genreIds: [2, 1]),
  Movie(id: 23, title: 'Дюна', originalTitle: 'Dune', year: 2021, duration: 155, rating: 7.8, licenseNumber: '121000023', studioId: 7, directorIds: [7], genreIds: [2, 7]),
  Movie(id: 24, title: 'Левиафан', originalTitle: 'Левиафан', year: 2014, duration: 140, rating: 7.3, licenseNumber: '121000024', studioId: 8, directorIds: [8], genreIds: [1]),
  Movie(id: 25, title: 'Елена', originalTitle: 'Елена', year: 2011, duration: 109, rating: 7.3, licenseNumber: '121000025', studioId: 8, directorIds: [8], genreIds: [1, 3]),
  Movie(id: 26, title: 'Нелюбовь', originalTitle: 'Нелюбовь', year: 2017, duration: 127, rating: 7.1, licenseNumber: '121000026', studioId: 8, directorIds: [8], genreIds: [1]),
  Movie(id: 27, title: 'Криминальное чтиво', originalTitle: 'Pulp Fiction', year: 1994, duration: 154, rating: 8.6, licenseNumber: '121000027', studioId: 10, directorIds: [9], genreIds: [6, 4]),
  Movie(id: 28, title: 'Бешеные псы', originalTitle: 'Reservoir Dogs', year: 1992, duration: 99, rating: 8.2, licenseNumber: '121000028', studioId: 10, directorIds: [9], genreIds: [6, 3]),
  Movie(id: 29, title: 'Джанго освобождённый', originalTitle: 'Django Unchained', year: 2012, duration: 165, rating: 8.2, licenseNumber: '121000029', studioId: 12, directorIds: [9], genreIds: [8, 1]),
  Movie(id: 30, title: 'Паразиты', originalTitle: 'Gisaengchung', year: 2019, duration: 132, rating: 8.0, licenseNumber: '121000030', studioId: 9, directorIds: [10], genreIds: [1, 4, 3]),
  Movie(id: 31, title: 'Воспоминания об убийстве', originalTitle: 'Salinui chueok', year: 2003, duration: 131, rating: 8.1, licenseNumber: '121000031', studioId: 9, directorIds: [10], genreIds: [6, 9, 1]),
  Movie(id: 32, title: 'Брат', originalTitle: 'Брат', year: 1997, duration: 100, rating: 8.3, licenseNumber: '121000032', studioId: 11, directorIds: [11], genreIds: [6, 1, 8]),
  Movie(id: 33, title: 'Брат 2', originalTitle: 'Брат 2', year: 2000, duration: 127, rating: 8.2, licenseNumber: '121000033', studioId: 11, directorIds: [11], genreIds: [6, 8, 4]),
  Movie(id: 34, title: 'Аватар', originalTitle: 'Avatar', year: 2009, duration: 162, rating: 8.0, licenseNumber: '121000034', studioId: 6, directorIds: [12], genreIds: [2, 7, 8]),
  Movie(id: 35, title: 'Титаник', originalTitle: 'Titanic', year: 1997, duration: 194, rating: 8.4, licenseNumber: '121000035', studioId: 6, directorIds: [12], genreIds: [1, 10]),
  Movie(id: 36, title: 'Терминатор 2: Судный день', originalTitle: 'Terminator 2: Judgment Day', year: 1991, duration: 137, rating: 8.3, licenseNumber: '121000036', studioId: 12, directorIds: [12], genreIds: [2, 8]),
  Movie(id: 37, title: 'Ирония судьбы, или С лёгким паром!', originalTitle: 'Ирония судьбы, или С лёгким паром!', year: 1975, duration: 184, rating: 8.2, licenseNumber: '121000037', studioId: 3, directorIds: [13], genreIds: [4, 10]),
  Movie(id: 38, title: 'Служебный роман', originalTitle: 'Служебный роман', year: 1977, duration: 159, rating: 8.3, licenseNumber: '121000038', studioId: 3, directorIds: [13], genreIds: [4, 10]),
  Movie(id: 39, title: 'Гараж', originalTitle: 'Гараж', year: 1979, duration: 95, rating: 7.9, licenseNumber: '121000039', studioId: 3, directorIds: [13], genreIds: [4]),
  Movie(id: 40, title: 'Мимино', originalTitle: 'Мимино', year: 1977, duration: 97, rating: 8.1, licenseNumber: '121000040', studioId: 3, directorIds: [14], genreIds: [4, 1]),
  Movie(id: 41, title: 'Кин-дза-дза!', originalTitle: 'Кин-дза-дза!', year: 1986, duration: 135, rating: 8.1, licenseNumber: '121000041', studioId: 3, directorIds: [14], genreIds: [2, 4]),
  Movie(id: 42, title: 'Афоня', originalTitle: 'Афоня', year: 1975, duration: 92, rating: 7.9, licenseNumber: '121000042', studioId: 3, directorIds: [14], genreIds: [4, 1]),
];

const seedViewers = <Viewer>[
  Viewer(id: 1, lastName: 'Иванов', firstName: 'Алексей', email: 'ivanov.a@mail.ru', phone: '+79161234501', card: ViewerCard(number: 'KT-100037', tariff: 'Премиум', visitsLeft: 24, issuedAt: '12.01.2026')),
  Viewer(id: 2, lastName: 'Смирнова', firstName: 'Мария', email: 'm.smirnova@yandex.ru', phone: '+79161234502', card: ViewerCard(number: 'KT-100074', tariff: 'Стандарт', visitsLeft: 10, issuedAt: '03.02.2026')),
  Viewer(id: 3, lastName: 'Кузнецов', firstName: 'Дмитрий', email: 'kuznetsov.d@gmail.com', phone: '+79161234503', card: ViewerCard(number: 'KT-100111', tariff: 'Базовый', visitsLeft: 4, issuedAt: '18.02.2026')),
  Viewer(id: 4, lastName: 'Попова', firstName: 'Анна', email: 'anna.popova@mail.ru', phone: '', card: ViewerCard(number: 'KT-100148', tariff: 'Стандарт', visitsLeft: 8, issuedAt: '25.02.2026')),
  Viewer(id: 5, lastName: 'Васильев', firstName: 'Игорь', email: 'i.vasiliev@yandex.ru', phone: '+79161234505', card: ViewerCard(number: 'KT-100185', tariff: 'Премиум', visitsLeft: 30, issuedAt: '01.03.2026')),
  Viewer(id: 6, lastName: 'Петрова', firstName: 'Елена', email: 'petrova.e@gmail.com', phone: '+79161234506', card: ViewerCard(number: 'KT-100222', tariff: 'Базовый', visitsLeft: 2, issuedAt: '14.03.2026')),
  Viewer(id: 7, lastName: 'Соколов', firstName: 'Павел', email: 'sokolov.p@mail.ru', phone: '+79161234507', card: ViewerCard(number: 'KT-100259', tariff: 'Стандарт', visitsLeft: 12, issuedAt: '02.04.2026')),
  Viewer(id: 8, lastName: 'Михайлова', firstName: 'Ольга', email: 'o.mikhailova@yandex.ru', phone: '', card: ViewerCard(number: 'KT-100296', tariff: 'Премиум', visitsLeft: 18, issuedAt: '20.04.2026')),
  Viewer(id: 9, lastName: 'Новиков', firstName: 'Сергей', email: 'novikov.s@gmail.com', phone: '+79161234509', card: ViewerCard(number: 'KT-100333', tariff: 'Базовый', visitsLeft: 0, issuedAt: '11.05.2026')),
  Viewer(id: 10, lastName: 'Фёдорова', firstName: 'Наталья', email: 'n.fedorova@mail.ru', phone: '+79161234510', card: ViewerCard(number: 'KT-100370', tariff: 'Стандарт', visitsLeft: 6, issuedAt: '29.05.2026')),
  Viewer(id: 11, lastName: 'Морозов', firstName: 'Артём', email: 'morozov.art@yandex.ru', phone: '+79161234511', card: ViewerCard(number: 'KT-100407', tariff: 'Базовый', visitsLeft: 5, issuedAt: '16.06.2026')),
  Viewer(id: 12, lastName: 'Волкова', firstName: 'Ксения', email: 'k.volkova@gmail.com', phone: '+79161234512', card: ViewerCard(number: 'KT-100444', tariff: 'Премиум', visitsLeft: 22, issuedAt: '07.07.2026')),
  Viewer(id: 13, lastName: 'Алексеев', firstName: 'Никита', email: 'alekseev.n@mail.ru', phone: '', card: ViewerCard(number: 'KT-100481', tariff: 'Стандарт', visitsLeft: 9, issuedAt: '21.08.2026')),
  Viewer(id: 14, lastName: 'Лебедева', firstName: 'Дарья', email: 'd.lebedeva@yandex.ru', phone: '+79161234514', card: ViewerCard(number: 'KT-100518', tariff: 'Базовый', visitsLeft: 3, issuedAt: '09.09.2026')),
];
