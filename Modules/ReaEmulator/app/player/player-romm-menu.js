// Generated from the vendored RomM EmulatorJS menu helpers and play translations (AGPL-3.0).
export function labelContextMenuButton(label) {
  const text =
    window.EJS_emulator?.elements?.bottomBar?.contextMenu?.[0]?.querySelector(
      ".ejs_menu_text",
    );
  if (text) text.innerText = label;
}

export function createQuickLoadButton(label) {
  const button = document.createElement("button");
  button.type = "button";
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("role", "presentation");
  svg.setAttribute("focusable", "false");
  svg.setAttribute("viewBox", "2 2 20 20");
  svg.innerHTML =
    '<path d="M12,7L17,12H14V16H10V12H7L12,7M19,21H5A2,2 0 0,1 3,19V5A2,2 0 0,1 5,3H19A2,2 0 0,1 21,5V19A2,2 0 0,1 19,21M19,19V5H5V19H19Z"></path>';
  const text = document.createElement("span");
  text.classList.add("ejs_menu_text");
  text.innerText = label;
  button.classList.add("ejs_menu_button");
  button.appendChild(svg);
  button.appendChild(text);

  const ejsMenuBar = document.querySelector("#game .ejs_menu_bar");
  const loadStateBtn = ejsMenuBar?.querySelector(
    ".ejs_menu_button:nth-child(5)",
  );
  if (ejsMenuBar && loadStateBtn) {
    ejsMenuBar.insertBefore(button, loadStateBtn);
  }

  return button;
}

export function createExitEmulationButton(label) {
  const button = document.createElement("button");
  button.type = "button";
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("role", "presentation");
  svg.setAttribute("focusable", "false");
  svg.innerHTML =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 460 460"><path style="fill:none;stroke-width:3;stroke-linecap:round;stroke-linejoin:round;stroke:rgb(255,255,255);stroke-opacity:1;stroke-miterlimit:4;" d="M 14.000061 7.636414 L 14.000061 4.5 C 14.000061 4.223877 13.776123 3.999939 13.5 3.999939 L 4.5 3.999939 C 4.223877 3.999939 3.999939 4.223877 3.999939 4.5 L 3.999939 19.5 C 3.999939 19.776123 4.223877 20.000061 4.5 20.000061 L 13.5 20.000061 C 13.776123 20.000061 14.000061 19.776123 14.000061 19.5 L 14.000061 16.363586 " transform="matrix(21.333333,0,0,21.333333,0,0)"></path><path style="fill:none;stroke-width:3;stroke-linecap:round;stroke-linejoin:round;stroke:rgb(255,255,255);stroke-opacity:1;stroke-miterlimit:4;" d="M 9.999939 12 L 21 12 M 21 12 L 18.000366 8.499939 M 21 12 L 18 15.500061 " transform="matrix(21.333333,0,0,21.333333,0,0)"></path></svg>';
  const text = document.createElement("span");
  text.classList.add("ejs_menu_text", "ejs_menu_text_right");
  text.innerText = label;
  button.classList.add("ejs_menu_button");
  button.appendChild(svg);
  button.appendChild(text);

  const ejsMenuBar = document.querySelector("#game .ejs_menu_bar");
  ejsMenuBar?.appendChild(button);

  return button;
}

export function createSaveQuitButton(label) {
  const button = document.createElement("button");
  button.type = "button";
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("role", "presentation");
  svg.setAttribute("focusable", "false");
  svg.setAttribute("viewBox", "2 2 20 20");
  svg.innerHTML =
    '<path d="M17,3H5A2,2 0 0,0 3,5V19A2,2 0 0,0 5,21H11.81C11.42,20.34 11.17,19.6 11.07,18.84C9.5,18.31 8.66,16.6 9.2,15.03C9.61,13.83 10.73,13 12,13C12.44,13 12.88,13.1 13.28,13.29C15.57,11.5 18.83,11.59 21,13.54V7L17,3M15,9H5V5H15V9M13,17H17V14L22,18.5L17,23V20H13V17"></path>';
  const text = document.createElement("span");
  text.classList.add("ejs_menu_text", "ejs_menu_text_right");
  text.innerText = label;
  button.classList.add("ejs_menu_button");
  button.appendChild(svg);
  button.appendChild(text);

  const ejsMenuBar = document.querySelector("#game .ejs_menu_bar");
  ejsMenuBar?.appendChild(button);

  return button;
}

export const menuLabels = {
  "bg_BG": {
    "context-menu": "Контекстно меню",
    "load-latest-state": "Зареждане на последното състояние",
    "quick-state-loaded": "Бързият запис от слота е зареден",
    "no-states-available": "Няма налични бързи записи",
    "resume-failed": "Избраното състояние не можа да бъде заредено. Играта започна отначало.",
    "state-incompatible-core": "Записан с {emulator}, което избраното ядро не може да зареди.",
    "quit": "Излез",
    "back-to-game-details": "Към детайлите на играта",
    "save-and-quit": "Запази и излез",
    "exit-full-screen": "Изход от цял екран",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Зареди запис или бърз запис",
    "loading": "Зареждане"
  },
  "cs_CZ": {
    "context-menu": "Kontextová nabídka",
    "load-latest-state": "Načíst poslední stav",
    "quick-state-loaded": "Rychlý stav načten",
    "no-states-available": "Nejsou k dispozici žádné stavy",
    "resume-failed": "Vybraný stav se nepodařilo načíst. Hra začala od začátku.",
    "state-incompatible-core": "Uloženo pomocí {emulator}, což vybrané jádro nedokáže načíst.",
    "quit": "Ukončit",
    "back-to-game-details": "Zpět k detailům hry",
    "save-and-quit": "Uložit a ukončit",
    "exit-full-screen": "Ukončit celou obrazovku",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Načíst uloženou pozici nebo stav",
    "loading": "Načítání"
  },
  "de_DE": {
    "context-menu": "Kontextmenü",
    "load-latest-state": "Letzten Zustand laden",
    "quick-state-loaded": "Schnellzustand geladen",
    "no-states-available": "Keine Zustände verfügbar",
    "resume-failed": "Der ausgewählte Spielstand konnte nicht geladen werden. Das Spiel wurde neu gestartet.",
    "state-incompatible-core": "Mit {emulator} gespeichert, was der gewählte Core nicht laden kann.",
    "quit": "Beenden",
    "back-to-game-details": "Zurück zu den Spieldetails",
    "save-and-quit": "Speichern und beenden",
    "exit-full-screen": "Vollbild beenden",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Spielstand oder Zustand laden",
    "loading": "Lädt"
  },
  "en_GB": {
    "context-menu": "Context menu",
    "load-latest-state": "Load latest state",
    "quick-state-loaded": "Quick state loaded",
    "no-states-available": "No states available",
    "resume-failed": "Could not load the selected state. The game started fresh.",
    "state-incompatible-core": "Saved with {emulator}, which the selected core cannot load.",
    "quit": "Quit",
    "back-to-game-details": "Back to game details",
    "save-and-quit": "Save and quit",
    "exit-full-screen": "Exit full screen",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Load save or state",
    "loading": "Loading"
  },
  "en_US": {
    "context-menu": "Context menu",
    "load-latest-state": "Load latest state",
    "quick-state-loaded": "Quick state loaded",
    "no-states-available": "No states available",
    "resume-failed": "Could not load the selected state. The game started fresh.",
    "state-incompatible-core": "Saved with {emulator}, which the selected core cannot load.",
    "quit": "Quit",
    "back-to-game-details": "Back to game details",
    "save-and-quit": "Save and quit",
    "exit-full-screen": "Exit full screen",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Load save or state",
    "loading": "Loading"
  },
  "es_ES": {
    "context-menu": "Menú contextual",
    "load-latest-state": "Cargar último estado",
    "quick-state-loaded": "Estado rápido cargado",
    "no-states-available": "No hay estados disponibles",
    "resume-failed": "No se pudo cargar el estado seleccionado. La partida comenzó desde cero.",
    "state-incompatible-core": "Guardado con {emulator}, que el core seleccionado no puede cargar.",
    "quit": "Salir",
    "back-to-game-details": "Volver a detalles",
    "save-and-quit": "Guardar y salir",
    "exit-full-screen": "Salir de pantalla completa",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Cargar partida o estado",
    "loading": "Cargando"
  },
  "fr_FR": {
    "context-menu": "Menu contextuel",
    "load-latest-state": "Charger le dernier état",
    "quick-state-loaded": "État rapide chargé",
    "no-states-available": "Aucun état disponible",
    "resume-failed": "Impossible de charger l'état sélectionné. La partie a démarré de zéro.",
    "state-incompatible-core": "Sauvegardé avec {emulator}, que le cœur sélectionné ne peut pas charger.",
    "quit": "Quitter",
    "back-to-game-details": "Retour aux détails du jeu",
    "save-and-quit": "Sauvegarder et quitter",
    "exit-full-screen": "Quitter le plein écran",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Charger une sauvegarde ou un état",
    "loading": "Chargement"
  },
  "hu_HU": {
    "context-menu": "Helyi menü",
    "load-latest-state": "Legutóbbi állapot betöltése",
    "quick-state-loaded": "Gyorsállás betöltve",
    "no-states-available": "Nincs elérhető állás",
    "resume-failed": "A kiválasztott állapot betöltése nem sikerült. A játék tiszta lappal indult.",
    "state-incompatible-core": "{emulator} emulátorral mentve, amit a kiválasztott mag nem tud betölteni.",
    "quit": "Kilépés",
    "back-to-game-details": "Vissza a játék részleteihez",
    "save-and-quit": "Mentés és Kilépés",
    "exit-full-screen": "Kilépés a teljes képernyőből",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Mentés vagy állás betöltése",
    "loading": "Betöltés"
  },
  "it_IT": {
    "context-menu": "Menu contestuale",
    "load-latest-state": "Carica ultimo stato",
    "quick-state-loaded": "Stato rapido caricato",
    "no-states-available": "Nessuno stato disponibile",
    "resume-failed": "Impossibile caricare lo stato selezionato. La partita è iniziata da zero.",
    "state-incompatible-core": "Salvato con {emulator}, che il core selezionato non può caricare.",
    "quit": "Esci",
    "back-to-game-details": "Ritorna ai dettagli del gioco",
    "save-and-quit": "Salva e esci",
    "exit-full-screen": "Esci dalla modalità a schermo intero",
    "stream-save-state-failed": "Non è stato possibile salvare lo stato.",
    "stream-load-state-failed": "Non è stato possibile caricare lo stato.",
    "load-save-or-state": "Carica salvataggio o stato",
    "loading": "Caricamento"
  },
  "ja_JP": {
    "context-menu": "コンテキストメニュー",
    "load-latest-state": "最新のステートをロード",
    "quick-state-loaded": "クイックステートをロードしました",
    "no-states-available": "利用可能なステートがありません",
    "resume-failed": "選択したステートを読み込めませんでした。ゲームは最初から開始されました。",
    "state-incompatible-core": "{emulator} で保存されたため、選択中のコアでは読み込めません。",
    "quit": "終了",
    "back-to-game-details": "ゲーム詳細へ戻る",
    "save-and-quit": "保存して終了",
    "exit-full-screen": "全画面表示を終了",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "セーブまたはステートセーブを読み込む",
    "loading": "読み込み中"
  },
  "ko_KR": {
    "context-menu": "컨텍스트 메뉴",
    "load-latest-state": "최근 상태 불러오기",
    "quick-state-loaded": "빠른 상태를 불러왔습니다",
    "no-states-available": "사용 가능한 상태 없음",
    "resume-failed": "선택한 상태를 불러오지 못했습니다. 게임이 처음부터 시작되었습니다.",
    "state-incompatible-core": "{emulator}(으)로 저장되어 선택한 코어에서 불러올 수 없습니다.",
    "quit": "종료",
    "back-to-game-details": "게임 설명으로 가기",
    "save-and-quit": "저장하고 종료",
    "exit-full-screen": "전체 화면 종료",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "세이브 또는 상태 불러오기",
    "loading": "불러오는 중"
  },
  "pl_PL": {
    "context-menu": "Menu kontekstowe",
    "load-latest-state": "Wczytaj ostatni stan",
    "quick-state-loaded": "Wczytano szybki stan",
    "no-states-available": "Brak dostępnych stanów",
    "resume-failed": "Nie udało się wczytać wybranego stanu. Gra rozpoczęła się od nowa.",
    "state-incompatible-core": "Zapisano w {emulator}, czego wybrany rdzeń nie może wczytać.",
    "quit": "Zakończ",
    "back-to-game-details": "Powrót do szczegółów gry",
    "save-and-quit": "Zapisz i zakończ",
    "exit-full-screen": "Zamknij tryb pełnoekranowy",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Wczytaj zapis lub stan",
    "loading": "Ładowanie"
  },
  "pt_BR": {
    "context-menu": "Menu de contexto",
    "load-latest-state": "Carregar último estado",
    "quick-state-loaded": "State rápido carregado",
    "no-states-available": "Nenhum estado disponível",
    "resume-failed": "Não foi possível carregar o estado selecionado. O jogo começou do zero.",
    "state-incompatible-core": "Salvo com {emulator}, que o core selecionado não consegue carregar.",
    "quit": "Sair",
    "back-to-game-details": "Voltar aos detalhes do jogo",
    "save-and-quit": "Salvar e sair",
    "exit-full-screen": "Sair da tela cheia",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Carregar save ou state",
    "loading": "Carregando"
  },
  "ro_RO": {
    "context-menu": "Meniu contextual",
    "load-latest-state": "Încarcă ultima stare",
    "quick-state-loaded": "Stare rapidă încărcată",
    "no-states-available": "Nicio stare disponibilă",
    "resume-failed": "Starea selectată nu a putut fi încărcată. Jocul a pornit de la zero.",
    "state-incompatible-core": "Salvat cu {emulator}, pe care nucleul selectat nu îl poate încărca.",
    "quit": "Ieși",
    "back-to-game-details": "Înapoi la detaliile jocului",
    "save-and-quit": "Salvează și ieși",
    "exit-full-screen": "Ieși din ecran complet",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Încarcă salvare sau stare",
    "loading": "Se încarcă"
  },
  "ru_RU": {
    "context-menu": "Контекстное меню",
    "load-latest-state": "Загрузить последнее состояние",
    "quick-state-loaded": "Быстрое состояние загружено",
    "no-states-available": "Нет доступных состояний",
    "resume-failed": "Не удалось загрузить выбранное состояние. Игра началась заново.",
    "state-incompatible-core": "Сохранено в {emulator}, выбранное ядро не может его загрузить.",
    "quit": "Выйти",
    "back-to-game-details": "Вернуться к деталям игры",
    "save-and-quit": "Сохранить и выйти",
    "exit-full-screen": "Выйти из полноэкранного режима",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Загрузить сохранение или состояние",
    "loading": "Загрузка"
  },
  "tr_TR": {
    "context-menu": "Bağlam menüsü",
    "load-latest-state": "Son durumu yükle",
    "quick-state-loaded": "Hızlı durum kaydı yüklendi",
    "no-states-available": "Mevcut durum kaydı yok",
    "resume-failed": "Seçilen durum yüklenemedi. Oyun sıfırdan başladı.",
    "state-incompatible-core": "{emulator} ile kaydedildi; seçili çekirdek bunu yükleyemez.",
    "quit": "Çık",
    "back-to-game-details": "Oyun ayrıntılarına dön",
    "save-and-quit": "Kaydet ve çık",
    "exit-full-screen": "Tam ekrandan çık",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "Kayıt veya durum kaydı yükle",
    "loading": "Yükleniyor"
  },
  "zh_CN": {
    "context-menu": "上下文菜单",
    "load-latest-state": "加载最新即时存档",
    "quick-state-loaded": "已加载快速即时存档",
    "no-states-available": "无可用状态",
    "resume-failed": "无法加载所选的存档状态。游戏已重新开始。",
    "state-incompatible-core": "由 {emulator} 保存，所选核心无法加载。",
    "quit": "退出",
    "back-to-game-details": "返回游戏详情",
    "save-and-quit": "保存并退出",
    "exit-full-screen": "退出全屏",
    "stream-save-state-failed": "无法保存该状态。",
    "stream-load-state-failed": "无法加载该状态。",
    "load-save-or-state": "加载存档或状态",
    "loading": "加载中"
  },
  "zh_TW": {
    "context-menu": "內容選單",
    "load-latest-state": "載入最新即時存檔",
    "quick-state-loaded": "已載入快速即時存檔",
    "no-states-available": "無可用即時存檔",
    "resume-failed": "無法載入所選的存檔狀態。遊戲已重新開始。",
    "state-incompatible-core": "由 {emulator} 儲存，所選核心無法載入。",
    "quit": "退出",
    "back-to-game-details": "返回遊戲詳情",
    "save-and-quit": "保存並退出",
    "exit-full-screen": "結束全螢幕",
    "stream-save-state-failed": "The state could not be saved.",
    "stream-load-state-failed": "The state could not be loaded.",
    "load-save-or-state": "載入存檔或即時存檔",
    "loading": "載入中"
  }
};
export const emulatorLanguages = ["af-FR", "ar-AR", "ben-BEN", "de-GER", "el-GR", "en-US", "es-ES", "fa-AF", "hi-HI", "it-IT", "ja-JA", "jv-JV", "ko-KO", "pt-BR", "ro-RO", "ru-RU", "tr-TR", "vi-VN", "zh-CN"];
