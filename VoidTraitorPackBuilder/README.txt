VOID TRAITOR PACK BUILDER

Что уже сделано:
- Custom содержит текущие собственные/неоднозначные файлы Void Traitor Pack.
- Сторонние моды из mods.json берутся заново из WorkshopMods\Installed.
- Build полностью пересоздаётся; Custom и Overrides никогда не удаляются.
- filelist.xml собирается из Custom/filelist.xml + filelist.xml сторонних модов.
- %ModDir% внутри вложенных модов автоматически получает нужную подпапку.
- Lua/Autorun стороннего legacy-Lua мода запускается через автоматически созданную обёртку с правильным путём мода.

Использование:
1. Дождись, пока Steam/Barotrauma обновит подписанные моды.
2. Запусти UPDATE PACK.bat.
3. Готовый пакет появится в Build\the void traitor pack.

СВОИ ФАЙЛЫ
Добавляй/редактируй их только в Custom. Если добавил новый XML-контент Barotrauma,
добавь соответствующую строку в Custom\filelist.xml.

OVERRIDES
Если ты изменяешь файл стороннего мода, положи его по тому же пути относительно
папки мода. Пример:
Overrides\NT Surgery Plus\Items\Medical\Consumables.xml

После обновления сначала копируется свежий Workshop-мод, затем Overrides заменяет
нужный файл. Overrides не удаляется при сборке.

mods.json
workshop_id — ID Workshop-мода.
target_folder — имя его папки внутри итогового Void Traitor Pack.
package_name — только контрольное имя; несовпадение выводит WARNING.
workshop_root можно оставить пустым: используется стандартная папка Barotrauma.

ОГРАНИЧЕНИЕ
Если сторонний мод использует LuaCs ModConfig.xml (новая схема Lua/C#/Config),
builder намеренно останавливается. Вложить такой ModConfig как обычную подпапку
нельзя: LuaCs его не загрузит как отдельный пакет. Это нужно обрабатывать отдельно,
а не молча собирать неработающий мод.
