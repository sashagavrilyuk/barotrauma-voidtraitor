-- CLIENT ONLY: статические тексты интерфейса Void Traitor Pack.
-- Динамические серверные сообщения, причины отказа и fallback для игроков без client Lua здесь не дублируются.

local language = {}

-- Общие кнопки и короткие подписи GUI
language.Common = {
    Ok = "OK",
    Cancel = "Отмена",
    Close = "Закрыть",
    Yes = "Да",
}

-- Основное меню Void Traitor
language.ClientMenu = {
    Title = "VOID TRAITOR",
    ShopButton = "SHOP",
    MainButton = "VT",
    ShopTooltip = "Открыть магазин Void Traitor",
    MainTooltip = "Открыть меню команд Void Traitor",
    NoCommands = "Список команд пока не получен от сервера.",
    GenericCommand = "Команда",
    DefaultConfirmTitle = "Подтверждение",
    Categories = {
        Main = "Основное",
        Character = "Персонаж",
        Round = "Раунд",
        Info = "Информация",
    },
    Actions = {
        role = { Label = "Моя роль", Hint = "Аналог !role / !traitor", Category = "Main" },
        points = { Label = "Очки и жизни", Hint = "Аналог !points", Category = "Main" },
        status = { Label = "Статус", Hint = "Аналог !status", Category = "Main" },
        toggletraitor = { Label = "Вкл/выкл предателя", Hint = "Аналог !toggletraitor", Category = "Main" },
        suicide = { Label = "Самоубийство", Hint = "Аналог !suicide / !kill / !death", Category = "Character", ConfirmTitle = "Подтверждение", ConfirmText = "Вы точно хотите убить своего персонажа?" },
        droppoints = { Label = "Сбросить поинты", Hint = "Аналог !droppoints", Category = "Character", InputHint = "Сколько поинтов сбросить?" },
        freehandcuffs = { Label = "Снять фальшивые наручники", Hint = "Аналог !freehandcuffs / !fhc", Category = "Character" },
        roundtime = { Label = "Время раунда", Hint = "Аналог !roundtime", Category = "Round" },
        locatesub = { Label = "Найти лодку", Hint = "Аналог !locatesub. Работает для монстров.", Category = "Round" },
        alive = { Label = "Живые игроки", Hint = "Аналог !alive. Работает для мертвых игроков.", Category = "Round" },
        players = { Label = "Игроки", Hint = "Аналог !players. Работает в Submarine Royale.", Category = "Round" },
        info = { Label = "Информация", Hint = "Аналог !info", Category = "Info" },
        playtime = { Label = "Время игры", Hint = "Аналог !playtime / !pt", Category = "Info" },
        stats = { Label = "Статистика", Hint = "Аналог !stats", Category = "Info" },
        version = { Label = "Версия мода", Hint = "Аналог !version", Category = "Info" },
    },
}

-- Административная вкладка клиентского меню
language.AdminMenu = {
    MainTab = "Основное",
    AdminTab = "Администратор",
    Categories = {
        Info = "Информация",
        Players = "Игроки",
        Roles = "Роли",
        GhostRoles = "Гост-роли",
        Events = "События",
    },
    Actions = {
        roundinfo = { Label = "Информация о раунде", Hint = "Аналог !roundinfo", Category = "Info" },
        roles = { Label = "Роли раунда", Hint = "Аналог !roles / !traitors", Category = "Info" },
        traitoralive = { Label = "Состояние предателей", Hint = "Аналог !traitoralive", Category = "Info" },
        allpoints = { Label = "Очки всех игроков", Hint = "Аналог !allpoints", Category = "Info" },
        ongoingevents = { Label = "Активные события", Hint = "Аналог !ongoingevents", Category = "Info" },
        endroundnow = { Label = "Закончить раунд сейчас", Hint = "Немедленно завершает раунд во время финального отсчёта Secret.", Category = "Info" },
        revive = { Label = "Оживить игрока", Hint = "Аналог !revive", Category = "Players" },
        void = { Label = "Отправить в пустоту", Hint = "Аналог !void", Category = "Players" },
        unvoid = { Label = "Вернуть из пустоты", Hint = "Аналог !unvoid", Category = "Players" },
        addpoint = { Label = "Добавить/убрать очки", Hint = "Аналог !addpoint", Category = "Players", InputHint = "Количество (+/-)" },
        addlife = { Label = "Добавить/убрать жизни", Hint = "Аналог !addlife", Category = "Players", InputHint = "Количество (+/-)" },
        giveghostrole = { Label = "Создать гост-роль", Hint = "Аналог !giveghostrole", Category = "GhostRoles", InputHint = "Название гост-роли" },
        assignrole = { Label = "Назначить роль предателя", Hint = "Аналог !assignrole", Category = "Roles" },
        triggerevent = { Label = "Запустить событие", Hint = "Аналог !triggerevent", Category = "Events" },
    },
    SelectedPlayer = "Игрок: %s",
    NoPlayers = "Нет подключённых игроков.",
    Alive = "Жив",
    Dead = "Мёртв",
    NoCharacter = "Нет персонажа",
    SelectRole = "Выберите роль",
    NoRoles = "Нет зарегистрированных ролей.",
    SelectEvent = "Выберите событие",
    NoEvents = "Нет зарегистрированных событий.",
    SelectCharacter = "Выберите персонажа",
    NoCharacters = "Нет живых персонажей.",
}

-- Клиентский интерфейс PointShop
language.Pointshop = {
    Categories = "КАТЕГОРИИ",
    BuyTab = "КУПИТЬ",
    Shop = "МАГАЗИН",
    Cart = "КОРЗИНА",
    Points = "ОЧКИ",
    Total = "ВСЕГО",
    After = "ПОСЛЕ ПОКУПКИ",
    Buy = "ПРИОБРЕСТИ",
    Clear = "ОЧИСТИТЬ ВСЁ",
    EmptyCart = "Корзина пуста",
    EmptyProducts = "В этой категории нет товаров",
    EmptyCategories = "Нет доступных категорий",
    ClickProduct = "Нажмите кнопку с корзиной, чтобы добавить товар. В корзине нажмите кнопку отмены, чтобы убрать одну штуку.",
    Stock = "В продаже",
    NoCategory = "Выберите категорию",
    SinglePurchase = "Этот товар можно добавить в корзину только один раз за покупку.",
    StockLimit = "Этот товар уже добавлен до лимита.",
    Balance = "БАЛАНС",
    Quantity = "Количество",
    ConfirmTitle = "ПОДТВЕРЖДЕНИЕ",
    ConfirmQuestion = "Купить выбранный товар?",
    ConfirmClassQuestion = "Выбрать этот класс?",
    Cancel = "ОТМЕНА",
    Cooldown = "Перезарядка",
    SelectGhostAction = "Выберите действие слева",
    SelectClassAction = "Выберите класс слева",
    Filter = "Фильтр",
    Search = "Поиск",
    FilterAll = "Все",
    FilterAvailable = "Доступные",
    FilterAffordable = "Могу купить",
    Price = "Цена",
    Remaining = "Остаток",
    Unlimited = "Без лимита",
    Category = "Категория",
    Unavailable = "Недоступно",
    NotEnoughPoints = "Недостаточно очков.",
}

-- Клиентский интерфейс гост-ролей
language.GhostRoles = {
    Title = "РОЛИ ПРИЗРАКОВ",
    Button = "Роли призраков (%d)",
    Points = "Очки",
    Price = "Цена",
    Free = "ДОСТУПНО",
    Taken = "ЗАНЯТО",
    Dead = "МЕРТВО",
    Take = "Запросить",
    Follow = "Следовать",
    Close = "Закрыть",
    Empty = "Сейчас нет зарегистрированных гост ролей.",
    SelectRole = "Выберите роль слева, чтобы увидеть подробное описание.",
    FreePrice = "Бесплатно",
    NotEnoughPoints = "Недостаточно очков",
}

-- Клиентский телепорт камеры наблюдателя
language.CameraTeleport = {
    Title = "ТЕЛЕПОРТ КАМЕРЫ",
    Button = "Телепорт камеры",
    Player = "Игрок",
    Follow = "Следовать",
    Close = "Закрыть",
    Empty = "Сейчас нет игроков с живым управляемым персонажем.",
}

-- Клиентский интерфейс голосований в лобби
language.Voting = {
    Button = "НАЧАТЬ ГОЛОСОВАНИЕ",
    Tooltip = "Открыть меню голосования в лобби",
    StartTitle = "Голосование",
    StartMode = "Голосование за режим",
    StartMap = "Голосование за подлодку",
    Close = "Закрыть",
    NoActive = "Сейчас нет активного голосования.",
    StartedBy = "Начал",
    Timer = "Осталось",
    Votes = "голосов",
    GameTitle = "Голосование за режим",
    MapTitle = "Голосование за подлодку",
}

return language
