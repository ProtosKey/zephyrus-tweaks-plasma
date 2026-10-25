# zephyrus-tweaks-plasma

Доработки для **ASUS ROG Zephyrus G16** под Arch Linux (система, на которой я тестировал) и KDE Plasma (Wayland). 

+ Горячие клавиши для смены режима подсветки и производительности
+ Рабочий режим Eco для дискретной видеокарты
+ Советы по снижению расхода батареи в простое

Требуется: `asusctl`, `rog-control-center`, `KDE Plasma 6` (`qdbus6`).

## Структура

+ `bin/rog-profile-next > ~/.local/bin`: Выбирает следующий профиль производительности через `asusctl` с подсказкой на экране
+ `bin/rog-aura-next > ~/.local/bin`: Выбирает следующий режим подсветки клавиатуры через `asusctl` с подсказкой на экране
+ `bin/rog-center-toggle > ~/.local/bin`: Открывает `rog-control-center`, а если он уже открыт, то закрывает
+ `kde/applications/*.desktop > ~/.local/share/applications`: Команды для горячих клавиш
+ `kde/environment.d/10-local-bin.conf > ~/.config/environment.d`: Добавляет скрипты в `PATH` графического сеанса
+ `system/dgpu-eco-cleanup > /usr/local/bin`: в режиме Eco убирает обесточенную дискретную видеокарту с шины `PCI`
+ `system/dgpu-eco-cleanup.service > /etc/systemd/system`: запускает скрипт выше при загрузке и перед каждым сном

## Установка

```sh
./install.sh           
./install.sh --system  
```

После установки выйдите из сеанса и зайдите снова, чтобы KDE подхватил новый PATH.

## Горячие клавиши

Параметры системы → **Комбинации клавиш** → Находим команду → **Add custom shortcut** → Нажимаем клавишу → **Apply**.

| Клавиша | Команда в KDE | Код клавиши |
|---|---|---|
| M4 | Control Center | `Launch (1)` |
| Fn+F4 | Keyboard Aura | `Launch (3)` |
| Fn+F5 | Performance Mode | `Launch (4)` |

### Как устроена горячая клавиша

1. **Скрипт** в `~/.local/bin`, исполняемый `chmod +x`.
2. **Ярлык** `.desktop` в `~/.local/share/applications` с `X-KDE-GlobalAccel-CommandShortcut=true` его создаёт окно «Добавить команду», можно написать руками (примеры в `kde/applications`).
3. **Привязка клавиши** в `~/.config/kglobalshortcutsrc` её пишет окно настроек, руками этот файл лучше не править, KDE держит привязки в памяти и может его перезаписать.

## Возможные ошибки


`Could not find the program`: графическая оболочка не нашла команду.

1. Опечатка: проверить правильность ввода
2. Скрипт вне PATH: добавить в PATH
3. KDE держит старую версию ярлыка: перезайти в сессию

## Режим Eco и зависание при сне

Приложение  `rog-control-center` в режиме `Eco` (`Integrated`) только пишет `dgpu_disable=1` в прошивку, которая **обесточивает** видеокарту, но устройство **остаётся на шине PCI**. В итоге драйвер пишет `GPU has fallen off the bus`. При засыпании ядро пытается разбудить мёртвую карту, сон зависает.

```sh
PM: Some devices failed to suspend, or early wake event detected
pci 0000:01:00.0: Unable to change power state from D3cold to D0, device inaccessible
```

Служба `dgpu-eco-cleanup` доделывает вторую половину работы: при `dgpu_disable=1` убирает все устройства NVIDIA с шины при загрузке и перед каждым сном.

В режиме Hybrid (`dgpu_disable=0`) она ничего не делает. Журнал: `journalctl -u dgpu-eco-cleanup`.

## Расход в простое

Найдено замерами `current_now * voltage_now` батареи и счётчиками `pmc_core`:

1. **Полоса Slash на крышке** на максимальной яркости потребляет **~3.5Вт–4Вт**

Для экономии заряда можно выключить.

```sh
asusctl slash set --disable
```

2. **Intel VMD** не даёт процессору глубоко спать
 
BIOS запрещает Linux управлять ASPM линии к NVMe `can't override BIOS ASPM; OS doesn't have ASPM control`, процессор застревает в PC2, счётчик `die_c6_us_show` не растёт. 

Найдено решение: BIOS: Advanced: VMD setup menu: **Disabled**. Экономит **~3Вт–4Вт**.

Windows с драйвером RST после этого не загрузится (`INACCESSIBLE_BOOT_DEVICE`). 

Можно перевести: при включённом VMD включить безопасный режим: в BIOS выключить VMD: загрузиться в безопасный режим: выключить безопасный режим: перезагрузка.

Включить безопасный режим.

```sh
bcdedit /set {current} safeboot minimal
```

Выключить безопасный режим. 

```sh
bcdedit /deletevalue {current} safeboot
```

3. Мелочи по **~0.3Вт–0.5Вт**: обесточенная видеокарта на шине, усилители динамиков с запретом засыпания, перерисовка экрана.

Проверить, что процессор спит глубоко: счётчик должен расти на миллионы мкс за **10с**.

```sh
sudo sh -c 'cat /sys/kernel/debug/pmc_core/die_c6_us_show; sleep 10; cat /sys/kernel/debug/pmc_core/die_c6_us_show'
```
