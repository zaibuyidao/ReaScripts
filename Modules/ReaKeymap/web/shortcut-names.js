'use strict';
// Display-only key names. Keep REAPER's original binding text for writes/exports.
// This factory is also embedded in the list worker for language-neutral lookup.
function createKeymapShortcutNames(){
  const locales=['en','zh-CN','zh-TW','ja','ko'];
  const entries=[
    ['Left','左','左','左','왼쪽',['LeftArrow','ArrowLeft','向左','左箭头','左箭頭']],
    ['Right','右','右','右','오른쪽',['RightArrow','ArrowRight','向右','右箭头','右箭頭']],
    ['Up','上','上','上','위',['UpArrow','ArrowUp','向上','上箭头','上箭頭']],
    ['Down','下','下','下','아래',['DownArrow','ArrowDown','向下','下箭头','下箭頭']],
    ['Space','空格','空格','スペース','스페이스',['Spacebar','空白']],
    ['Enter','回车','Enter','Enter','Enter',['Return','回車']],
    ['Esc','Esc','Esc','Esc','Esc',['Escape','退出']],
    ['Tab','Tab','Tab','Tab','Tab',['制表符','制表']],
    ['Backspace','退格','退格','Backspace','Backspace',[]],
    ['Delete','删除','刪除','Delete','Delete',['Del']],
    ['Insert','插入','插入','Insert','Insert',['Ins']],
    ['Home','Home','Home','Home','Home',[]],
    ['End','End','End','End','End',[]],
    ['Page Up','上翻页','上翻頁','Page Up','Page Up',['PageUp','PgUp','Prior','向上翻页','向上翻頁']],
    ['Page Down','下翻页','下翻頁','Page Down','Page Down',['PageDown','PgDn','Next','向下翻页','向下翻頁']],
    ['Caps Lock','大写锁定','大寫鎖定','Caps Lock','Caps Lock',['CapsLock']],
    ['Num Lock','数字锁定','數字鎖定','Num Lock','Num Lock',['NumLock']],
    ['Scroll Lock','滚动锁定','捲動鎖定','Scroll Lock','Scroll Lock',['ScrollLock','滾動鎖定']],
    ['Print Screen','打印屏幕','列印螢幕','Print Screen','Print Screen',['PrintScreen','PrtSc','PrtScn']],
    ['Pause','Pause','Pause','Pause','Pause',['Break','暂停','暫停']],
    ['Mousewheel','鼠标滚轮','滑鼠滾輪','マウスホイール','마우스 휠',['Mouse wheel','鼠標滾輪']],
    ['HorizWheel','水平滚轮','水平滾輪','水平ホイール','가로 휠',['Horizontal mousewheel','水平鼠标滚轮','水平滑鼠滾輪']]
  ];
  for(const [key,aliases] of [...Array.from({length:10},(_,i)=>[String(i),['Keypad'+i,'Numpad'+i]]),['+',['KeypadAdd','NumpadAdd']],['-',['KeypadSubtract','NumpadSubtract']],['*',['KeypadMultiply','NumpadMultiply']],['/',['KeypadDivide','NumpadDivide']],['.',['KeypadDecimal','NumpadDecimal']],['Enter',['KeypadEnter','NumpadEnter']],['=',['KeypadEqual']]]){
    entries.push(['Num '+key,'小键盘 '+key,'小鍵盤 '+key,'テンキー '+key,'숫자패드 '+key,aliases.concat('数字键盘'+key,'數字鍵盤'+key)]);
  }
  const compact=value=>String(value).toLowerCase().replace(/\s+/g,'');
  const aliases=new Map();
  for(const entry of entries)for(const name of [...entry.slice(0,5),...entry[5]])aliases.set(compact(name),entry);
  function format(value,locale='en'){
    let key=String(value??'').trim(),prefix='';
    // Consume modifiers only; splitting on every '+' would corrupt Num +.
    while(true){const match=/^(Ctrl|Control|Shift|Alt|Option|Opt|Win|Cmd|Command|Super|Meta)\s*\+\s*/i.exec(key);if(!match)break;prefix+=match[1]+'+';key=key.slice(match[0].length);}
    const entry=aliases.get(compact(key));
    return prefix+(entry?entry[Math.max(0,locales.indexOf(locale))]:key);
  }
  const searchCache=new Map();
  function searchText(value){
    if(!searchCache.has(value)){
      if(searchCache.size>=4096)searchCache.delete(searchCache.keys().next().value);
      searchCache.set(value,[...new Set(locales.map(locale=>format(value,locale)))].join('\n'));
    }
    return searchCache.get(value);
  }
  return {format,searchText};
}
window.KeymapShortcutNames=createKeymapShortcutNames();
