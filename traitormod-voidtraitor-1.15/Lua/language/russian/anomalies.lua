local language = ...
-- окна сканера, сосуда и генератора аномалий (по русской локализации SS14)
language.AnomalyClose = "Закрыть"
language.AnomalyError = "ОШИБКА"
language.AnomalyScannerTitle = "Сканер аномалий"
language.AnomalySeverity = "Текущая опасность: %s"
language.AnomalyStability = "Состояние аномалии: %s"
language.AnomalyStabilityLow = "распад"
language.AnomalyStabilityMedium = "стабильное"
language.AnomalyStabilityHigh = "рост"
language.AnomalyPoints = "Пассивная генерация очков в секунду: %s"
language.AnomalyParticleReadout = "Реакция на частицы:"
language.AnomalyParticleDanger = "- Опасный тип: %s"
language.AnomalyParticleUnstable = "- Нестабильный тип: %s"
language.AnomalyParticleContainment = "- Сдерживающий тип: %s"
language.AnomalyParticleTransformation = "- Трансформирующий тип: %s"
language.AnomalyParticles = { delta = "дельта-частицы", epsilon = "эпсилон-частицы", zeta = "зета-частицы", sigma = "сигма-частицы" }
language.AnomalyBehaviorTitle = "Отклонения поведения:"
language.AnomalyBehaviorUnknown = "ОШИБКА. Невозможно считать."
language.AnomalyBehaviorPoints = "Аномалия даёт %d%% очков"
language.AnomalyBehaviors = {
    Balanced = "Отклонений не обнаружено.",
    FullSafe = "Аномалия чрезвычайно стабильна. Импульсы крайне редки.",
    Slow = "Импульсы заметно реже.",
    Light = "Импульсы заметно слабее.",
    DelayedForce = "Импульсы заметно реже, но сильнее.",
    Rapid = "Импульсы заметно чаще, но слабее.",
    BalancedSecret = "Обнаружены помехи. Часть данных не считывается.",
    NonSensivity = "Слабая реакция на частицы.",
    Sensivity = "Сильная реакция на частицы.",
    Fast = "Импульсы заметно чаще.",
    Strenght = "Импульсы заметно сильнее.",
    Inconstancy = "Непостоянство: со временем типы частиц меняются.",
    InconstancyParticle = "Непостоянство: со временем типы частиц меняются.",
    FullUnknown = "Обнаружены помехи. Часть данных не считывается.",
    FastUnknown = "Импульсы заметно чаще.",
    InconstancyParticleUnknown = "Непостоянство: со временем типы частиц меняются.",
    Jumping = "Координатная нестабильность: аномалия перемещается.",
    JumpingUnknown = "Координатная нестабильность: аномалия перемещается.",
}
language.AnomalyPulseTimer = "До следующего импульса: %s"
language.AnomalySupercritical = "Аномалия переходит в сверхкритическое состояние!"
language.AnomalyVesselTitle = "Сосуд аномалий"
language.AnomalyVesselEmpty = "Сосуду не присвоена аномалия. Возьмите в руку сканер, которым её просканировали."
language.AnomalyVesselLinked = "Сосуду присвоена аномалия."
language.AnomalyVesselOutput = "Выработка: %d очков в секунду"
language.AnomalyVesselNoPower = "Нет питания: очки не идут"
language.AnomalyVesselNoServer = "Сервер РНД не принимает очки"
language.AnomalyVesselLink = "Присвоить аномалию со сканера"
language.AnomalyGeneratorTitle = "Генератор аномалий"
language.AnomalyGeneratorFuel = "Топливо: %d (%s)"
language.AnomalyGeneratorCooldown = "Перезарядка: %s"
language.AnomalyGeneratorReady = "Перезарядка: завершена"
language.AnomalyGeneratorNoPower = "Нет питания"
language.AnomalyGeneratorGenerating = "Создание аномалии…"
language.AnomalyGeneratorCreated = "Аномалия создана! Она где-то на станции."
language.AnomalyGeneratorGenerate = "Создать аномалию"
-- объявление события «Аномалия» (в SS14 — AnomalySpawn)
language.AnomalySpawnAnnouncement = "Наши датчики засекли опасную межпространственную аномалию на борту станции. Сообщите научному отделу %s."
language.AnomalySightings = {
    "о низком пульсирующем гуле по всей станции",
    "о странных источниках света",
    "о необъяснимых очертаниях",
    "о формах, вызывающих сильную тревогу",
    "о странных явлениях вокруг",
}
