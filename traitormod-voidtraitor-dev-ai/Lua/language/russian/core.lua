-- SERVER ONLY: этот файл используется только серверной локализацией VoidTraitor.
-- Клиентские статические подписи GUI находятся в Void traitor pack/Lua/language/russian.lua.
local language = ...

-- Советы и справка
language.TipText = "Совет: "
language.Tips = {
    "Вы можете использовать !pointshop чтобы стать сувществом, когда вы мертвы.",
    "У предателей есть доступ в свой особый магазин. Используйте !pointshop чтобы открыть его.",
    "Вы можете использовать !role чтобы получить информацию о статусе вашей конкретной роли.",
    "Вы можете использовать !help чтобы получить список всех доступных команд.",
    "Вы можете использоватьe !write чтобы написать сообщение, которое останется в кпк после вашей смерти.",
    "Капитан и Оффицеры Службы Безопасности не могут быть предателями.",
    "Роли станут доступны когда вы умрете, вы можете использовать !ghostrole чтобы использовать их.",
    "Использование команды !kill в чате просто переносит вас обратно в список наблюдателей, не убивая роль.",
    "Смерть в первые 15 секунд после перерождения за существо полностью возмещает его стоимость.",
  	"У нас есть свой сервер в дискорде! Там сможете пообщаться с нами и возможно что то предложить для сервера. https://discord.gg/rFrwmXg8DQ"
}

-- Справка по командам
language.Help = "\n!help - показывает это сообщение помощи\n!helptraitor - показывает все команды предателя\n!helpadmin - показывает все команды администратора\n!traitor - показывает информацию о предателе\n!pointshop или !shop - открывает магазин очков\n!points - показывает ваши очки и жизни\n!status - показывает ваши навыки и активные временные эффекты\n!alive - показывает список живых игроков (только во время смерти)\n!locatesub - показывает расстояние и направление подводной лодки, только для монстров\n!ghostrole - команда чтоб вселиться в гостроль (как надо !ghostrole pirate)\n!suicide - убивает вашего персонажа\n!version - показывает текущую версию трейтормода\n!write - записывает в ваш журнал смерти\n!roundtime - показывает текущее время раунда !startgamevote - начинает голосование за режим в лобби."
language.HelpTraitor = "\n!toggletraitor - переключает, может ли игрок быть выбран предателем\n!tc [msg] - отправляет сообщение всем предателям\n!tannounce [msg] - отправляет объявление для предателей\n!tdm [Имя] [msg] - отправляет анонимное сообщение данному игроку"
language.HelpAdmin = "\n!traitoralive - проверить, все ли предатели умерли\n!roundinfo - показать информацию о раунде (спойлер!)\n!endroundnow - немедленно завершить Secret во время финального отсчёта\n!allpoints - показывает количество очков у всех подключенных клиентов\n!addpoint [Client] [+/-Amount] - добавить очки клиенту\n!addlife [Client] [+/-Amount] - добавить жизнь(и) клиенту\n! оживить [клиент] - оживить персонажа данного клиента\n!void [имя персонажа] - отправить персонажа в пустоту\n!unvoid [имя персонажа] - вернуть персонажа из пустоты\n!vote [текст] [опция1] [опция2] [...] - начать голосование на сервере\n!giveghostrole [текст] [персонаж] - назначить персонажа с указанным именем на роль призрака."

-- Статус персонажа
language.StatusTitle = "Статус персонажа"
language.StatusSkillsHeader = "Навыки:"
language.StatusEffectsHeader = "Активные временные эффекты:"
language.StatusNoEffects = "- Нет активных временных эффектов"
language.StatusAliveRequired = "Вы должны быть живы, чтобы использовать эту команду."
language.StatusUnknownEffect = "Неизвестный эффект"
language.StatusSkillLine = "- %s: %d"
language.StatusSkillLineWithBonus = "- %s: %d + %d = %d"
language.StatusEffectLine = "- %s — %s"
language.StatusSkillWeapons = "Оружие"
language.StatusSkillMechanical = "Механика"
language.StatusSkillElectrical = "Электрика"
language.StatusSkillMedical = "Медицина"
language.StatusSkillSurgery = "Хирургия"
language.StatusSkillHelm = "Управление"

-- Тестовый режим и базовые состояния
language.TestingMode = "Режим тестирования 1P - нельзя набрать или потерять очки"
language.CMDSwitchTestAvailable = "Для переключения команды используйте !switchtest."
language.CMDSwitchTestUnavailable = "Команда !switchtest доступна только в тестовом режиме Attack Defends или Пряток, когда на сервере один активный игрок."
language.CMDSwitchTestChanged = "Тестовая команда переключена: %s."
language.RoundNotStarted = "Раунд не начался"
language.ReceivedPoints = "Вы получили %s очков"
language.Alive = "Жив"
language.Dead = "Мертв"

-- Возрождение посреди раунда
language.MidRoundSpawnWelcome = ">> Возрождение посреди раунда активно! <<\n\nРаунд уже начался, но вы можете появиться мгновенно!"
language.MidRoundSpawn = "Вы хотите появиться мгновенно или дождаться следующего раунда?\n"
language.MidRoundSpawnMission = "> Возродиться"
language.MidRoundSpawnCoalition = "> Возродиться в Коалиции"
language.MidRoundSpawnSeparatists = "> Возродиться у сепаратистов"
language.MidRoundSpawnWait = "> Ждать"

-- Очки, опыт и жизни
language.PointsInfo = "У вас %s очков и %s/%s жизней"
language.Points = " (%s очков)"
language.Experience = " (%s опыта)"
language.SkillsIncreased = "Хорошая работа по улучшению ваших навыков"
language.PointsAwarded = "Вы получили %s очков"
language.PointsAwardedRound = "В этом раунде вы получили:\n%s очков"
language.ExperienceAwarded = "Вы получили %s опыта"
language.LivesGained = "Вы набрали %s. Теперь у вас есть %s/%s жизней"
language.ALife = "жизнь"
language.Lives = " жизни"
language.Death = "Вы потеряли жизнь. У вас осталось %s, прежде чем вы потеряете очки"
language.NoLives = "Вы потеряли все свои жизни. В результате вы потеряли часть очков"
language.MaxLives = "У вас максимальное количество жизней"

-- Общие ответы и состояния целей
language.CommandTip = "(Введите !traitor в чате, чтобы показать это сообщение снова)"
language.CommandNotActive = "Эта команда деактивирована"
language.Completed = "(Завершено)"
language.Failed = "(Провалено)"
language.SubObjective = "Доп. цели (необязательные):"
language.HuskNewObjective = "Ваша следующая цель - %s"

-- Серверные события и объявления
language.AbyssHelpPart1 = "Входящий сигнал бедствия... п---гит-! -ы -----яли в безд-- и н-м н--на -о--щь бл-к-рат-р за--щил нас вн--. Вз--ен м- предл---ем что-н--удь, ч-о у н-с е--ь, вк-ю-ая н-ши ---0 оч-ков"
language.AbyssHelpPart2 = "Передача прерывается сразу после этого."
language.AbyssHelpPart3 = "Не могу поверить, что мы выбрались живыми, спасибо вам большое! Вот очки, которые я обещал, возьмите этот грузовой скутер и журнал внутри. В журнале должны быть обещанные очки"
language.AbyssHelpPart4 = "Вот дерьмо! Кто-то пришел! Огромное спасибо! Пожалуйста, найдите способ вытащить нас отсюда, я дам вам %s моих очков, если вы сможете вытащить меня живым."
language.AbyssHelpPart5 = "Вы можете попробовать достать новый аккумулятор для этой подводной лодки и починить ее."
language.AbyssHelpDead = "Думаю, этим все и закончится...."
language.AmmoDelivery = "В оружейную зону субмарины доставлены боеприпасы и снаряды для рельсотрона."
language.BeaconPirate = "Поступили сообщения о печально известном пирате в УЗК, терроризирующем эти воды. Недавно пират был обнаружен на станции маяка - уничтожьте пирата, чтобы получить награду в %s очков для всего экипажа."
language.WreckPirate = "Поступили сообщения о печально известном пирате в УЗК, терроризирующем эти воды, недавно пират был обнаружен внутри затонувшей подводной лодки - ликвидируйте пирата, чтобы получить награду в %s очков для всего экипажа."
language.PirateInside = "Внимание! Опасный пират в УЗК был обнаружен внутри главной подводной лодки!"
language.PirateKilled = "Пират в УЗК убит, команда получила награду в %s очков."
language.UPCPirate = "Вы должны защищать это место чтобы получить %s поинтов, так же вы можете попытаться напасть на подлодку."
language.UPCPirateObjective = "Защищайте это место, чтобы получить %s поинтов в конце раунда, либо идите на главную подлодку. Если вы лично убьёте весь экипаж, который находится на ней, вы получите %s поинтов. Если лодка пуста, удерживайте её изнутри %s секунд и получите %s поинтов за захват."
language.PirateEliminatedCrew = "Пират в УЗК уничтожил весь экипаж на подлодке и получил %s поинтов. Экипаж провалил раунд."
language.PirateCaptureStarted = "Пират в УЗК начал захват подлодки. Вернитесь в течение %s секунд, иначе экипаж провалит раунд."
language.PirateCaptureInterrupted = "Захват подлодки пиратом в УЗК был сорван."
language.PirateCapturedSubmarine = "Пират в УЗК захватил подлодку и получил %s поинтов. Экипаж провалил раунд."
language.ClownMagic = "Вы чувствуете странное ощущение, и внезапно оказываетесь в другом месте"
language.CommunicationsOffline = "Что-то вмешивается во все наши системы связи. По оценкам, связь будет отключена не менее чем на %s минут."
language.CommunicationsBack = "Связь восстановлена"
language.EmergencyTeam = "Группа инженеров и механиков прибыла на подводную лодку, чтобы помочь с ремонтом"
language.ElectricalFixDischarge = "Неизвестная сила отремонтировала необходимые для выживания устройства на подводной лодке. Судя по всему это были фиксики, теперь у вас на 33% починены устройства."
language.FixHull = "Неизвестная сила отремонтировала весь корпус на подводной лодке. Судя по всему это были корпусные-фиксики, теперь у вас корпус починился на 50 едениц."
language.FullElectricalFixDischarge = "Неизвестная сила отремонтировала необходимые для выживания устройства на подводной лодке. Судя по всему фиксики устали смотреть как вы умераете, теперь у вас на 100% починены устройства."
language.FullFixHull = "Неизвестная сила отремонтировала весь корпус на подводной лодке. Судя по всему корпусные-фиксики устали смотреть как вы умераете, теперь у вас корпус починился на 1000 едениц."
language.BreackElectrical = "вам сломали электронику на 33% (wip)"
language.BreackHull = "вам сломали корпус на 50 едениц (wip)"
language.KillElectrical = "вам сломали электронику на 100% (wip)"
language.KillHull = "вам сломали корпус на 1000 едениц (wip)"
language.LightsOff = "Все огни внезапно погасли, но питание по-прежнему включено? Что происходит?"
language.MaintenanceToolsDelivery = "В грузовой отсек корабля доставлены инструменты для технического обслуживания. Инструменты находятся в желтом ящике"
language.MedicalDelivery = "В медицинский отсек корабля доставлено медицинское оборудование. Медицинские принадлежности находятся в красном медицинском ящике"
language.PrisonerAboard = "На борту подводной лодки находится заключенный, держите его живым и в наручниках, пока подводная лодка не прибудет в пункт назначения, чтобы команда получила %s очков"
language.PrisonerYou = "Вы - заключенный! Если вам удастся отойти от подводной лодки на 500 метров, вы будете вознаграждены суммой в размере %s очков."
language.PrisonerSuccess = "Заключенный был успешно доставлен, экипаж получил награду в %s очков."
language.PrisonerFail = "Заключенный сбежал, и награда за транспортировку была отменена"
language.OxygenSafe = "Кислород из генератора кислорода теперь снова безопасен для дыхания"
language.OxygenHusk = "Кислородный генератор был саботирован и теперь содержит яйца трупных паразитов. У тех, кто дышит этим воздухом есть около 15 секунд, чтобы достать подводную маску или скафандр, прежде чем вы получите достаточно большую дозу!"
language.OxygenPoison = "Кислородный генератор был саботирован и теперь содержит страданит. У тех, кто дышит этим воздухом есть около 15 секунд, чтобы достать подводную маску или скафандр, прежде чем вы получите достаточно большую дозу!"
language.PirateCrew = "Внимание! В этих водах замечен пиратский корабль! Уничтожьте пиратский реактор или убейте всех пиратов, чтобы получить награду в %s очков для всего экипажа"
language.EmergencyYou = "Вы являетесь частью команды (Аварийной команды)! Вы должны починить подлодку даже ценной ваша жизни и не дать умереть оставшейся команде на этой подводной лодке! (Помните вы не должны убивать обидчиков или гриферить на подлодке!)"
language.PirateCrewYou = "Вы являетесь частью пиратской команды этой подводной лодки! Защитите подводную лодку от любых грязных коалиций, пытающихся получить то, что принадлежит вам!"
language.PirateCrewSuccess = "Пираты сдались, команда получила награду в %s очков."
language.InvisibilityTraitor = "ПРЕДУПРЕЖДЕНИЕ! На корабле замечен очень странная одежда, будьте на настороже, она имеет странные свойста. Мы заметили что странные сигнатуры видны через тепловизор."
language.FriendPet = "Вы являетесь питомцем! Вы должны служить людям и защищать людку от тварей! (Помните вы не должны убивать обидчиков или гриферить на подлодке!)"
language.ShadyMissionPart1 = "Вы засекли странную радиопередачу, похоже, они ищут кого-то, кто выполнит для них работу."
language.ShadyMissionPart2 = "\"О, привет! Мы ищем человека, который выполнит для нас одно простое задание. Мы готовы заплатить за него до 3000 очков. Заинтересованы?\""
language.ShadyMissionPart2Answer = "Конечно! Что это?"
language.ShadyMissionPart3 = "\"В этом районе, куда направляется ваша подводная лодка, есть старая разбитая подводная лодка, где нам нужно разместить некоторые припасы. Поскольку сейчас у нас нет припасов, вам придется достать их самостоятельно. Нам понадобится минимум 8 любых медицинских предметов, 4 кислородных баллона, 2 заряженных пистолета любого типа и специальный гидролокационный маяк. За эти припасы мы заплатим 1500 очков, если вы добавите другие припасы, мы дадим вам до 1500 дополнительных очков.\""
language.ShadyMissionPart3Answer = "Звучит подозрительно, зачем вам понадобилось класть эти припасы в затонувшую подводную лодку?!"
language.ShadyMissionPart4 = "\"Теперь это не твое дело, сделаешь ты это или нет?\""
language.ShadyMissionPart4AnswerAccept = "Принять предложение"
language.ShadyMissionPart4AnswerDeny = "Отклонить предложение"
language.ShadyMissionPart5 = "\"Отлично! Просто положите все припасы и специальный сонарный маяк в металлический ящик и оставьте его на затонувшем корабле.\""
language.ShadyMissionPart5Answer = "Я сделаю все возможное"
language.ShadyMissionBeacon = "‖color:gui.red‖Кажется, маяк был модифицирован.\nСзади висит записка, гласящая: \"8 Медицинских предмета, 4 Кислороднх баллона и 2 заряженых пушки.\"‖color:end‖"
language.SuperBallastFlora = "В этой области обнаружена высокая концентрация спор балластной флоры, рекомендуется обыскать насосы на предмет балластной флоры!"
language.Answer = "Ответить"
language.Ignore = "Игнорировать"
language.ItemsBought = "Предметы, купленные в магазине"
language.CrewBoughtItem = "Игроки купили предметы в магазине"
language.PointsGained = "Общее количество набранных очков"
language.PointsLost = "Общее количество потерянных очков"
language.Spawns = "Появившиеся игроки"
language.CrewDeaths = "Смерти"
language.Rounds = "Общая статистика раунда"
language.Yes = "Да"
language.No = "Нет"

-- Способности профессий и случайные эффекты
language.AbilityNoTurretSlots = "На этой подлодке нет свободных слотов под эту пушку."
language.ReactorShutdown = "На реакторе произошёл критический сбой, и он отключился для самосохранения."
language.SupercapacitorFailure = "Из-за короткого замыкания на суперконденсаторы прилетело 220v. Они вышли из строя и потеряли весь запас энергии."
language.JunctionBoxOverload = "Из-за сбоя в реакторе на электрощитки прилетело огромное напряжение. Все щитки требуют ремонта."
language.OxygenSufforin = "В кислородной системе появился опасный реагент. Воздух кажется неправильным."
language.OxygenParalyzant = "Кто-то испортил кислородную систему. Воздух вызывает тревогу."
language.OxygenMorbusine = "Кислородная система была саботирована. Воздух ощущается токсичным."
language.OxygenCyanide = "Кислородная система была саботирована. Воздух внезапно стал смертельно опасным."
language.WeakBallastFlora = "Слабая форма балластной флоры заразила несколько балластных насосов."
language.CaptainHelmBoost = "Вы чувствуете воодушевление, теперь вы намного лучше управляете подлодкой на 5 минут."
language.SecurityMindSense = "Вы чувствуете странные ощущения, теперь вы можете 5 минут видеть всех сквозь стены, но у этого есть побочный эффект..."
language.MechanicMechanicalRepair = "Механик позвал фиксиков помочь с ремонтом, но они не очень старались и починили всю механику на 15%."
language.MechanicHullRepair = "Механик позвал корпусных фиксиков помочь с ремонтом, и они починили весь корпус на 50%."
language.MechanicSkillBoost = "Вы чувствуете воодушевление, теперь вы намного лучше чините корпус и механику на 5 минут."
language.EngineerElectricalRepair = "Инженер позвал фиксиков помочь с ремонтом, но они не очень старались и починили всю электрику на 10%."
language.EngineerSkillBoost = "Вы чувствуете воодушевление, теперь вы намного лучше чините электроприборы на 5 минут."
language.MedicSkillBoost = "Вы чувствуете воодушевление, теперь вы намного лучше занимаетесь медициной и можете хирургировать на 5 минут."
language.SurgeonSkillBoost = "Вы чувствуете воодушевление, теперь вы намного лучше хирургируете на 5 минут."
language.SecurityTurretInstalled = "Служба безопасности установила %s на свободный слот турели."
language.EuropeanForceTurretInstalled = "Европейская сила установила %s на свободный слот турели."
language.VentCreaturesWarning = "Где-то в вентиляции раздаются чужие шорохи и тихий скрежет. Внутри точно кто-то есть."
language.ClownCrateWarning = "На подлодке появился подозрительный клоунский ящик."
language.ClownCrateMonster = "Клоунский ящик открылся, и оттуда выпрыгнуло что-то опасное."
language.ClownCratePet = "Клоунский ящик открылся, и оттуда вылез странный питомец."
language.ClownCrateNpc = "Клоунский ящик открылся, и внутри оказался очень растерянный человек."
language.ClownCrateLoot = "Клоунский ящик раскрылся и вывалил добычу из поинтшопа."
language.RescueSuccess = "Спасение прошло успешно. Каждый живой член экипажа получил %s очков."
language.RescueFail = "Операция по спасению провалилась."
language.WreckRescue = "В разрушенной подлодке замечен выживший. Доставьте его живым на основную лодку, и каждый живой член экипажа получит %s очков."
language.BeaconRescue = "На маяке замечен выживший. Доставьте его живым на основную лодку, и каждый живой член экипажа получит %s очков."
language.RescueYou = "Останьтесь в живых и доберитесь до основной подлодки. Если вы спасётесь, экипаж получит награду."
language.WreckRescueName = "Выживший из обломков"
language.BeaconRescueName = "Выживший с маяка"

-- Команды: ответы, usage и ошибки
language.CMDLocatePlayer = "Игрок %s находится в %s м от вас, направление %s, на %s."
language.CMDPlaytime = "Ваше время в игре: %s."
language.FakeHandcuffsUsage = "Вы можете освободиться от этих наручников, используя !fhc"
language.Pets = "Питомцы"
language.SmallCreatures = "Мелкие существа"
language.LargeCreatures = "Крупные существа"
language.AbyssCreature = "Существо бездны"
language.ElectricalDevices = "Электрические устройства"
language.MechanicalDevices = "Механические устройства"
language.CMDAliveToUse = "Вы должны быть живы, чтобы использовать эту команду"
language.CMDAliveDeadOnly = "Вы должны быть мертвы, чтобы использовать эту команду, если у вас нет прав администратора."
language.CMDNoRole = "У вас нет особой роли"
language.CMDAlreadyDead = "Вы уже мертвы!"
language.CMDHandcuffed = "Вы не можете использовать эту команду, пока скованы наручниками"
language.CMDKnockedDown = "Вы не можете использовать эту команду, пока вы без сознания"
language.GamemodeNone = "Режим игры: Нет"
language.CMDPermisionPoints = "У вас нет прав на добавление очков"
language.CMDInvalidNumber = "Неверное значение числа"
language.CMDClientNotFound = "Не удалось найти клиента с этим именем / steamID"
language.CMDCharacterNotFound = "Не удалось найти персонажа с указанным именем"
language.CMDAdminAddedPointsEveryone = "Администратор добавил %s очков всем"
language.CMDAdminAddedPoints = "Администратор добавил %s очков %s"
language.CMDAdminAddedLives = "Администратор добавил %s жизней %s"
language.CMDOnlyMonsters = "Только монстры могут использовать эту команду"
language.CMDLocateSub = "Подводная лодка находится на расстоянии %sм от вас, в %s"
language.CMDRoundTime = "Этот раунд длится уже %s минут"
language.CMDMonsterBroadcast = "[%s %s]: %s"
language.UnknownCommand = "Неизвестная команда. Напишите !help, чтобы посмотреть список доступных команд."
language.MonsterBeaconDescription = "‖color:196, 90, 32, 255‖Модифицированный сонарный маяк. Если оставить его активным на 30 секунд, он приманит стаю чудовищ снаружи подлодки.‖color:end‖"
language.ReachedClassLimit = "Достигнут лимит класса"
language.CMDVersion = "Запущен Evil Factory's Traitor Mod v%s"
language.Unknown = "Неизвестно"
language.CommandError = "Ошибка команды: %s"
language.CMDFreeHandcuffsDead = "Вы мертвы!"
language.CMDFreeHandcuffsNotFake = "Эти наручники не фальшивые!"
language.CMDDeathLogUnable = "Вы не можете писать в журнал смерти."
language.CMDDeathLogWrote = "Записано в журнал смерти: \"%s\"."
language.CMDMidRoundAlreadySpawned = "Вы уже появлялись."
language.CMDMidRoundNotInGame = "Вы не в игре."
language.CMDTraitorChatUsage = "Использование: !tc [сообщение]"
language.CMDTraitorAnnounceUsage = "Использование: !tannounce [сообщение]"
language.CMDTraitorDirectMessageUsage = "Использование: !tdm [имя] [сообщение]"
language.CMDTraitorDirectMessageNameNotFound = "Имя не найдено."
language.CMDInGameToUse = "Вы должны быть в игре, чтобы использовать эту команду."
language.CMDPlayersSubmarineRoyaleOnly = "Эта команда доступна только в Submarine Royale."
language.CMDVoteUsage = "Использование: !vote \"Текст\" \"Вариант 1\" \"Вариант 2\" ... \"Вариант N\""
language.CMDVoteResultsHeader = [=[Результаты голосования: %s

]=]
language.CMDVoteResultsLine = [=[%s: %s голосов
]=]
language.CMDAllPointsLine = "%s: %s очков - %s веса"
language.CMDAddPointUsage = "Неверное количество аргументов. Использование: !addpoint \"Имя клиента\" 500"
language.CMDAddLifeUsage = "Неверное количество аргументов. Использование: !addlife \"Имя клиента\" 1"
language.CMDAlreadyMaximumLives = "У %s уже максимальное количество жизней."
language.CMDCharacterDeadOrMissing = "Персонаж клиента мёртв или отсутствует."
language.CMDVoidSent = "Персонаж отправлен в войд."
language.CMDVoidNotInVoid = "Этот персонаж не находится в войде."
language.CMDVoidRemoved = "Персонаж убран из войда."
language.CMDReviveSuccess = "Персонаж %s оживлён и получил 1 жизнь обратно."
language.CMDReviveAnnounce = "Администратор оживил %s."
language.CMDReviveNotDead = "Персонаж %s не мёртв."
language.CMDReviveNotFound = "Персонаж %s не найден."
language.CMDOngoingEvents = "Текущие события: "
language.CMDGiveGhostRoleUsage = "Использование: !giveghostrole <название гост роли> <персонаж>"
language.CMDAssignRoleCharacterUsage = "Использование: !assignrole <персонаж> <роль>"
language.CMDAssignRoleClientUsage = "Использование: !assignrole <клиент> <роль>"
language.CMDAssignRoleNotFound = "Не удалось найти роль для назначения."
language.CMDAssignRoleSuccess = "Игроку %s назначена роль %s."
language.CMDTriggerEventUsage = "Использование: !triggerevent <название события>"
language.CMDTriggerEventNotFound = "Событие %s не существует."
language.CMDTriggerEventSuccess = "Запущено событие %s."
language.CMDOClock = "%s часов"
language.CMDMonsterUsage = "Использование: !monster сообщение"
language.CMDCommandCooldown = "Подождите немного перед повторным использованием этой команды."
language.CMDDropPointsUsage = "Использование: !droppoints количество"
language.CMDDropPointsInvalidAmount = "Укажите корректное число от 100 до 100000."
language.CMDDropPointsNotEnough = "У вас недостаточно очков для сброса."
language.CMDDropPointsFailed = "Не удалось выбросить очки. Попробуйте ещё раз."
language.CMDDropPointsDropped = "Выброшено %s очков."

-- Системные сообщения сервера
language.ChatSenderServer = "Сервер"
language.WelcomeMessage = [=[Добро пожаловать в Void Traitor!

Это не обычный сервер с предателями, а довольно разнообразный и уникальный в своем роде сервер.
Так как здесь стоит собственный Traitor Mod с кучами разными изменениями и даже с целыми режимами.
Здесь мы играем в «Миссии с предателями», «attack & defend», иногда страдаем шизой!

Также у меня есть дискорд-сервер, где я упоминаю, когда сервер открыт, и там можно скачать мод на меню для Traitor Mod. 
P.S. Еще там есть гайды, и вы можете предложить, что можно добавить еще на сервер:
мой сервер - https://discord.gg/rFrwmXg8DQ
сервер партнеров Project Encelada - https://discord.gg/encelada

Если хотите легче покупать, то можно поставить:
Traitor menu (Для работы нужен клиентский LUA вместе С#)
https://steamcommunity.com/sharedfiles/filedetails/?id=2990694897

(ВВОДИТЬ В ЧАТ И БЕЗ "/") Команды:
!help - выводит список команд
!point - показывает поинты, шанс и жизни
!pointshop / !shop / !ps - магазин
!traitor - выводит список заданий
!suicide / !kill - чтобы умереть.

Правила!!!
Запрещено быть мудаком.
Запрещено гриферить и убивать, когда ты не предатель.
СБ И КАПИТАНЫ НЕ МОГУТ БЫТЬ ПРЕДАТЕЛЯМИ!!]=]

-- Описания специальных предметов
language.ItemDescriptionCultistBeacon = "‖color:160, 32, 240, 255‖Модифицированный сонарный маяк. На нём написано: \"Оставь активным на 30 секунд для сюрприза.\"‖color:end‖"
language.ItemDescriptionActiveHuskEggs = "Крайне активные яйца хаска."
language.ItemDescriptionExplosiveAutoInjector = "Модифицированный блок C-4, который можно положить внутрь автоинжекторной гарнитуры."
language.ItemDescriptionTeleporterRevolver = "‖color:gui.red‖Особый револьвер с функциями телепортации...‖color:end‖"

-- Команда статистики
language.CMDStatsDefaultCategory = "Статистика"
language.CMDStatsNoStats = "Статистика не найдена."
language.CMDStatsAvailable = "Доступная статистика:"
language.CMDStatsNoneAvailable = "Статистика пока недоступна. Начните раунд, чтобы собрать статистику."
language.CMDStatsUsage = "Введите '!stats [option]', чтобы показать статистику."
language.CMDStatsLobbyOnly = "Статистика недоступна в раунде. Используйте эту команду в лобби."
language.CMDStatsUnavailable = "Статистика ещё не загружена."
