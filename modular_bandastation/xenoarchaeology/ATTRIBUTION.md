# Источники ксеноархеологии

Код и спрайты портированы из [Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506)
(Jackriip и участники Voidcrew, коммит `cfde23a6397c667b73e73a680a503b425bf3a169`, AGPL-3.0).
Voidcrew собрал их из NovaSector (порт TauCeti), Polaris и VOREStation; спрайты — под CC BY-SA 3.0.
Источники состояний ниже указаны по комментариям донора в `artifact_appearance.dm` и `specimen_crate.dm`.

## `icons/artifacts.dmi`

| Состояния | Источник |
| --- | --- |
| `pylon`, `terminal`, `vents`, `growth`, `crystal_green`, `crystal_violet`, `crystal_blue` (+ `_active`) | NovaSector `5ce2bd2215c0`, `artifacts.dmi`, состояния 7–13 |
| `torus`, `monolith`, `spire`, `idol`, `cradle`, `effigy`, `spindle` (+ `_active`) | Polaris `6cd19fe0dec6`, `xenoarchaeology.dmi`: `ano10`, `ano70`, `ano80`, `ano120`, `ano130`, `ano140`, `ano150` |
| `shard` | Aurora, `crystal_madness` |
| `shard_active` | нарисован для Voidcrew на основе `crystal_madness` |
| `label_tag` | [Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506) |

Донор сообщает, что состояния, восходящие к Goonstation (Nova `artifact_1`–`6`, Bay/Polaris
`ano00`/`20`/`30`/`40`/`50`), не используются.

## `icons/specimen_crate.dmi`

Перекраска ящика /tg/station (`icons/obj/storage/crates.dmi`, `crate`/`crateopen`) для Voidcrew;
состояния `manifest` и `welded` скопированы из того же файла /tg/station.

## Раскопки (`icons/dig_*.dmi`, `icons/curios.dmi`)

Источники — по комментариям донора в `code/dig/`; где донор не указал первоисточник, ссылка на
[Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506).

| Файл / состояния | Источник |
| --- | --- |
| `curios.dmi`: малые находки | Polaris `6cd19fe0dec6`, `icons/obj/xenoarchaeology.dmi` |
| `curios.dmi`: `strange_rock_*` | Polaris `6cd19fe0dec6`, `icons/obj/xenoarchaeology.dmi` `strange`, стадии отколов — Voidcrew |
| `dig_site.dmi`: `vein1`–`vein3` | Baystation12 `excavation_overlays.dmi` `overlay_archaeo1`–`3`, перекрашены Voidcrew |
| `dig_site.dmi`: валуны, колышки, отвал, поле, метки | [Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506) |
| `dig_tools.dmi` | NovaSector `5ce2bd2215c0`, `xenoarch_items.dmi` и `tools.dmi` (стабилизатор — `anoscanner_borg`) |
| `dig_machines.dmi` | NovaSector `5ce2bd2215c0`, `machinery.dmi` (спектрометр), открытая панель — Voidcrew |
| `dig_finds.dmi` | NovaSector `5ce2bd2215c0`, `artifacts.dmi` (кристалл ядра), перекрашен и с обмоткой — Voidcrew |
| `dig_scan.dmi` | [Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506) |

## Изучение (`icons/study.dmi`)

NovaSector `5ce2bd2215c0`, `modular_nova/modules/xenoarchartifacts/icons/machinery.dmi` (через TauCetiClassic,
CC BY-SA 3.0); состояния без питания, с открытой панелью и свечения отредактированы для
[Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506). Маркировщик и ленты — Voidcrew PR #506.

## Использование (`icons/use.dmi`)

NovaSector `5ce2bd2215c0`, `machinery.dmi` (сборщик, `particles_battery`), CC BY-SA 3.0; маски купола и ядра
батареи нарисованы для [Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506). Луч сбора —
обесцвеченный `drain_life` из /tg/station. Утилизатор — Voidcrew PR #506.

## Резонатор (`icons/resonator*.dmi`)

Оригинальные спрайты пояса с оборудованием: предмет, пояс на персонаже и обе руки.
Нарисованы непосредственно в 32×32 для Primera, 2026-11-11; CC BY-SA 3.0.
Свечение использует отдельные маски, окрашиваемые по виду энергии батареи.
