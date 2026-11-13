# Источники космической овермапы

Атрибуция новых материалов `space_overmap`. Общая навигация указана в
[overmap/ATTRIBUTION.md](../overmap/ATTRIBUTION.md), биомы — в
[expedition_planets/ATTRIBUTION.md](../expedition_planets/ATTRIBUTION.md), корабли — в
[overmap_ships/ATTRIBUTION.md](../overmap_ships/ATTRIBUTION.md), руины — в
[overmap_ruins/ATTRIBUTION.md](../overmap_ruins/ATTRIBUTION.md).

## Лицензии и авторы

Исходный код и адаптации используют GNU AGPL v3; полный текст уже находится в
корневом [LICENSE](../../LICENSE). Исторические GPL-компоненты сохраняют условия
источника. Для планировок и графики сохраняется CC BY-SA 3.0; включённый исходный
код сохраняет лицензию кода донора. Исключения отдельных ресурсов не отменяются.

| Источник и авторы | Версия и лицензионная политика |
| --- | --- |
| SierraBay/SierraBay12, участники SierraBay и Baystation | [8623b35f6943130998002e94cf001a9c6ccb3f4c](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/README.md#лизцензия) |
| Void-Crew/Voidcrew-LRP, участники Voidcrew, Shiptest, Whitesands и TG | [66c552922bf2a28963c2a8f5d89993623a141a1f](https://github.com/Void-Crew/Voidcrew-LRP/blob/66c552922bf2a28963c2a8f5d89993623a141a1f/README.md#license) |
| CeladonSS13/Shiptest, участники Celadon, Shiptest, Whitesands и TG | [4214796c7289b74779f10dd25df2d695c264aa8f](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/README.md) |
| ParadiseSS13/Paradise, участники Paradise | [8e4ad940e497f64443c3fc635a09840a8fa7a1d2](https://github.com/ParadiseSS13/Paradise/blob/8e4ad940e497f64443c3fc635a09840a8fa7a1d2/README.md#licenses) |
| TG, BandaStation и Primera contributors | [65a9bd040b816783f0b6c24ba1e84ee7aab48456](https://github.com/SpaceStation220/Primera/blob/65a9bd040b816783f0b6c24ba1e84ee7aab48456/README.md#license) |

[Полный текст CC BY-SA 3.0](LICENSE-ASSETS-CC-BY-SA-3.0.txt),
[официальная страница лицензии](https://creativecommons.org/licenses/by-sa/3.0/).
Указание авторства не означает одобрения этой адаптации исходными проектами.

## Орбитальные планеты экспедиции

`icons/planets.dmi`: пять слоёв 480×480, адаптированных непосредственно из пикселей
`icons/effects/parallax.dmi` участников TG, BandaStation и Primera
([исходник](https://github.com/SpaceStation220/Primera/blob/84ad68cbd1f99c5021af540407d1de5389651f6d/icons/effects/parallax.dmi)).
Адаптация StationTrauma, 2026-11-06; арт-дирекция Junkkky. Лицензия — CC BY-SA 3.0.
Ледяная планета сохраняет штатный кадр `icemoon` без изменений. Каменистая,
пустынная и зелёная используют его пиксельные узоры с изменёнными палитрами,
кратерами и материками. Лавовая сохраняет рисунок штатного `planet` без луны
и обломков; перекрытые ими участки восстановлены, палитра очищена до пяти цветов.
Масштабирование и реалистичное текстурирование не применялись. Исходный DMI
не изменён; его звёзды, туманности и астероиды используются как прежде.

## Термоядерное ядро Raven

`icons/fusion_core.dmi`: нативная пиксельная отрисовка 96×96 для StationTrauma,
2026-11-06, по предметным референсам и арт-дирекции Junkkky. Образец палитры и
манеры отрисовки — существующий `icons/obj/machines/cannon.dmi`, авторы TG и
BandaStation. Корпус неподвижен; анимируются только энергия и аварийные лампы.
Отдельные маски используются для emissive. Лицензия нового ресурса — CC BY-SA 3.0.
Фотографии-референсы в ресурс не копировались.

Звуки ядра переиспользуют существующие ресурсы сборки:
`sound/machines/hypertorus/loops/hypertorus_nominal.ogg` и
`sound/machines/sm/loops/{calm_start,calm_end,delamming}.ogg`.
Их исходные авторство и лицензии сохраняются; новых аудиофайлов не добавлено.

## Космические локации

| Локальный файл | Источник |
| --- | --- |
| `maps/asteroid_field.dmm` | Собственная планировка StationTrauma на штатных ресурсах сборки |
| `maps/drift_cargo.dmm` | Собственная планировка StationTrauma на штатных ресурсах сборки |

`asteroid_field.dmm` и `drift_cargo.dmm` созданы для этой интеграции на штатных
ресурсах. Существующие TG-руины подключаются по исходным шаблонам без копирования
графики и изменения их лицензий.

[ASSETS.json](ASSETS.json) перечисляет 92 неаудиоресурса: две карты локаций,
семь карт аванпостов, тестовый зал,
78 деталей рельефа планет (их источники указаны в
[expedition_planets/ATTRIBUTION.md](../expedition_planets/ATTRIBUTION.md)),
`icons/obj/fluff/map_previews.dmi`, `icons/fusion_core.dmi`, `icons/planets.dmi`
и `icons/trade_terminal.dmi`.
Реестр содержит permalink, коммиты и SHA-256
исходников и локальных файлов.
Превью карт создаётся штатным генератором и сохраняет авторство исходных карт и
ресурсов; это не самостоятельно нарисованная новая графика.

CRT-оформление TGUI и SVG-индикаторы созданы кодом для адаптации. Растровые
референсы других игр в модуль не включены. Штатные компьютерные спрайты, иконки,
шрифты и остальные существующие ресурсы сохраняют свои исходные уведомления.

## Торговые узлы

`_maps/map_files/debug/trade_hubs.dmm` — новая планировка тестового зала BandaStation
со штатными стенами, полами, декалями и объектами сборки. Заимствованных планировок
и новых внешних изображений нет; используются существующие ресурсы TG/BandaStation,
CC BY-SA 3.0, с сохранением исходных уведомлений.

`maps/trade_outpost_*.dmm` — семь новых аванпостов на штатных ресурсах TG/BandaStation,
CC BY-SA 3.0.

`icons/trade_terminal.dmi` — новый спрайт терминала, созданный встроенным генератором
изображений OpenAI по предметному референсу пользователя, 2026-11-06. Образцы стиля —
штатные машины TG/BandaStation (`icons/obj/machines/computer.dmi`, `vending.dmi`,
`nuke_terminal.dmi`). Спрайт приведён к 32×48 пикселям и доработан автором референса.
Корпус общий, включённые и разбитые экраны вынесены в отдельные
слои. Полный вид для редактора карты находится в том же DMI. Референс в репозиторий
не включён. Лицензия нового ресурса — CC BY-SA 3.0.

## Звуки корабля

### Кнопки навигационной консоли

`sound/navigation_button.wav` — собственный звук Junkky__ (Junkkky), предоставленный
автором 2026-11-08 как `SK_BUTTON_INTERFACE_SC-FI (mp3cut.net).wav`.
Автор подтвердил, что сделал запись сам. Для совместимости с BYOND стереозапись
float32 сведена в моно PCM16; частота 48 кГц и длительность 0,843 с сохранены.
Рычаг тяги использует прежний штатный щелчок.

### Звуки двигателя

`sound/engine/` содержит звуки маршевых двигателей, которые проигрывает
`code/ship_audio.dm`. Внешние варианты — исходные записи после сведения в моно,
нормализации пика к −1 дБ и конвертации в OGG Vorbis. Внутренние варианты получены
из внешних низкочастотным фильтром (срез около 700 Гц) с подъёмом низа под 150 Гц;
петли обработаны по кругу, чтобы стык остался бесшовным.

| Локальные файлы | Исходная запись | Автор и условия |
| --- | --- | --- |
| `engine_exterior_start.ogg`, `engine_interior_start.ogg` | `SFX_REACTORS_TAKE-ON_SPACESHIP.wav` | vycksounds (Vyck21) |
| `engine_exterior_idle.ogg`, `engine_interior_idle.ogg` | `SFX_REACTORS_IDLE_SPACESHIP(L).wav` | vycksounds (Vyck21) |
| `engine_exterior_stop.ogg`, `engine_interior_stop.ogg` | `SFX_REACTORS_LAND_SPACESHIP.wav` | vycksounds (Vyck21) |
| `engine_exterior_thrust.ogg`, `engine_interior_thrust.ogg` | «Plane Loop», громкость приведена к петле холостого хода | qubodup, [Freesound 184723](https://freesound.org/people/qubodup/sounds/184723/), CC0 1.0 |

Записи vycksounds взяты из набора [Spaceship SFX](https://vycksounds-21.itch.io/spaceship-sfx)
(«SB SPACESHIP TRAVEL»). Условия автора: файлы можно использовать в некоммерческих
и коммерческих проектах, но нельзя продавать отдельно, как есть, в том числе после
изменения; автор просит указывать «vycksounds(Vyck21)». Эти файлы не распространяются
по CC BY-SA 3.0 и сохраняют условия автора.

### Существующие ресурсы сборки

Остальные звуки берутся из сборки без копирования и изменения. Для них сохраняются
исходные уведомления:

| Назначение | Ресурс сборки | Источник и лицензия |
| --- | --- | --- |
| Розжиг камеры сгорания | `sound/items/jet_ignite.ogg` | kyles, [Freesound 453408](https://freesound.org/people/kyles/sounds/453408/), CC0; обработка ArcaneMusic, см. [sound/attributions.txt](../../sound/attributions.txt) |
| Продувка камеры сгорания | `sound/items/jet_active.ogg` | Тот же источник, CC0; очистка шума, небольшое изменение высоты тона, нарезка и конвертация в OGG указаны в исходном уведомлении |
| Фон внутри корпуса | `sound/ambience/general/shipambience.ogg` | Существующий фон `/area`, участники TG; [общая лицензия ресурсов сборки](../../README.md#license), CC BY-SA 3.0 |
| Посадка и стыковка | `sound/machines/airlock/airlock_latch_hiss.ogg` | Usernameis1337, [Freesound 632755](https://freesound.org/people/Usernameis1337/sounds/632755/), CC BY 4.0; см. [исходное уведомление](../../sound/machines/airlock/attributions.txt) |

Ранее добавленные `sound/ship_engine_starts.ogg`, `sound/ship_engine_processing.ogg`,
`sound/ship_engine_stops.ogg`, `sound/ship_interior_ambience.ogg` и
`sound/ship_landing.ogg` удалены: их точный источник и условия распространения не
подтверждены. Реестр `ASSETS.json` остаётся реестром неаудиоресурсов.

## Границы записи

Подводные модули и неизменённые ресурсы основной Primera целиком здесь не аудируются.

`ASSETS.json` не содержит AI-комментариев, поскольку JSON их не допускает.
Текст лицензии скопирован без изменений и не размечается AI-комментариями.
