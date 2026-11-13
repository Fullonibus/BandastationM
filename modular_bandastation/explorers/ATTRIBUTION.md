# Источники экспедиционного корпуса

## Полевая форма

Спрайты участников SierraBay и Baystation из
[SierraBay/SierraBay12, c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037](https://github.com/SierraBay/SierraBay12/tree/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037):

| Файл модуля | Исходник |
| --- | --- |
| `icons/uniforms.dmi` | [maps/sierra/icons/obj/obj_under_exploration.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/icons/obj/obj_under_exploration.dmi) |
| `icons/uniforms_worn.dmi` | [maps/sierra/icons/mob/onmob_under_exploration.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/icons/mob/onmob_under_exploration.dmi) |

Файлы скопированы без изменения пикселей или DMI-метаданных. Привязка четырёх
вариантов формы к должностям адаптирована к системе одежды TG/BandaStation.

## Остальной полевой гардероб

Из того же коммита SierraBay/SierraBay12 извлечены только используемые состояния:

| Файлы модуля | Исходники SierraBay/SierraBay12 |
| --- | --- |
| `head.dmi`, `head_worn.dmi` — пилотский шлем | [obj_head.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_head.dmi), [onmob_head.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_head.dmi) |
| `shoes.dmi`, `shoes_worn.dmi` — служебные ботинки | [obj_feet.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_feet.dmi), [onmob_feet.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_feet.dmi) |
| `gloves.dmi`, `gloves_worn.dmi` — рабочие перчатки | [obj_hands.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_hands.dmi), [onmob_hands.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_hands.dmi) |
| `suits.dmi`, `suits_worn.dmi` — куртка | [obj_suit.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_suit.dmi), [onmob_suit.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_suit.dmi) |
| `accessories.dmi`, `accessories_worn.dmi` — разгрузка, ножны `holster_machete` | [obj_accessories.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_accessories.dmi), [onmob_accessories.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_accessories.dmi) |

Авторство графики сохраняется за участниками SierraBay/Baystation. Кадры извлечены
без перерисовки, масштабирования или перекраски; совпадение пикселей проверено.
Изменена упаковка DMI; открытое состояние куртки переименовано из `_open` в `_t`
для штатного переключателя TG. Карманы и хранение работают через имеющуюся систему TG.
Исключение — ножны с клинком: состояние `holster_machete-full` (предмет и четыре направления на теле)
дорисовано поверх ножен Sierra рукоятью мачете в цветах нашего мачете (`machete.dmi`); в исходнике Sierra
такого состояния нет. С запада ножны закрыты телом, и рукоять там не рисуется.

Состав взят из [шкафов НТ-эксплореров](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/structures/closets/exploration.dm)
и их [стартовых наборов](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/job/outfits.dm).
Механические свойства адаптированы на основе местных ботинок, перчаток, шлема,
одежды и storage; системы инвентаря и военных званий Bay не переносились.

Лицензия графики — [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/),
согласно [лицензионной политике источника](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/README.md#лизцензия).
Полный текст уже включён в [space_overmap/LICENSE-ASSETS-CC-BY-SA-3.0.txt](../space_overmap/LICENSE-ASSETS-CC-BY-SA-3.0.txt).

## Мачете

Состояние `machete` извлечено без изменения пикселей из того же коммита SierraBay/SierraBay12:
[melee_physical.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/weapons/melee_physical.dmi),
[lefthand.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/items/lefthand.dmi),
[righthand.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/items/righthand.dmi).
Файлы модуля: `machete.dmi`, `machete_lefthand.dmi`, `machete_righthand.dmi`.
Авторство SierraBay/Baystation, лицензия графики CC BY-SA 3.0, упаковка DMI изменена.
Механика местного `/obj/item/hatchet`; материалы и парирование Bay не переносились.

## MOD-костюмы

`mod.dmi` и `mod_worn.dmi`. Шлемы и A-Unit — спрайты SierraBay/SierraBay12 (тот же коммит),
корпуса, перчатки, ботинки и блоки управления — перекрашенные в цвета корпуса MOD-спрайты:

| Костюм | Шлем | Остальное |
| --- | --- | --- |
| Полевой (`expedition`) | войдсьют эксплорера Sierra: [obj_head_solgov.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/torch/icons/obj/obj_head_solgov.dmi), [onmob_head_solgov.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/torch/icons/mob/onmob_head_solgov.dmi), без изменений; визор — вырезанное стекло этого шлема | `tsf_standart` форка (`modular_bandastation/objects/icons/*/clothing/modsuit/mod_clothing.dmi`): синее → фиолетовое, огни → жёлтые, корпус рюкзака → тёмно-серый |
| Пилот (`expedition_pilot`) | войдсьют пилота Sierra: [obj_head.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_head.dmi), [onmob_head.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_head.dmi), перекрашен, стекло не тронуто | `magnate` TG (`icons/*/clothing/modsuit/mod_clothing.dmi`) |
| Медик (`expedition_medic`) | `rescue` TG, насыщеннее синий | `rescue` TG: белое → тёмно-серое, яркие блики → фиолетовые |
| Инженер (`expedition_engineer`) | `prototype` TG | `prototype` TG: тёмные сине-серые пластины → фиолетовые |
| Тяжёлый «A-Unit» (`expedition_heavy`) | `safeguard` TG, перекрашен в палитру A-Unit (серые — по светлоте, красное — в фиолетовый, огни — в жёлтый) | риг `command_exp_rig` Sierra без изменений: [uniques.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/icons/obj/uniques.dmi), [onmob_rig_back.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_rig_back.dmi) и torch `obj_/onmob_` `suit`, `hands`, `feet` |

Перекраска — попиксельная замена тона и насыщенности, без перерисовки формы; кадры, задержки и
петли анимаций сохранены. Авторство: SierraBay/Baystation, tgstation и авторы спрайтов TSF форка;
лицензия графики CC BY-SA 3.0. Расстановка хранилищ повторяет [EVA эксплореров Sierra](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/machinery/machinery.dm);
броня, замедление и модули — на системе MOD TG.

## Полевое снаряжение

Из того же коммита SierraBay/SierraBay12 без изменения пикселей:

| Файл модуля и состояния | Исходник |
| --- | --- |
| `gear.dmi`, `gear_worn.dmi`: `bio_anom`, `bio_anom_hood` | [obj_suit.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_suit.dmi), [obj_head.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_head.dmi), [onmob_suit.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_suit.dmi), [onmob_head.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_head.dmi) |
| `gear_lefthand.dmi`, `gear_righthand.dmi` | [lefthand.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/items/lefthand.dmi), [righthand.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/items/righthand.dmi), [lefthand_hats.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/items/lefthand_hats.dmi), [righthand_hats.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/items/righthand_hats.dmi) |
| `machete.dmi`: `machetedx` | [melee_physical.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/weapons/melee_physical.dmi) |

Состав [шкафчиков](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/structures/closets/exploration.dm)
по Sierra, переписан на системах TG. Авторство SierraBay/Baystation, лицензия графики CC BY-SA 3.0.
