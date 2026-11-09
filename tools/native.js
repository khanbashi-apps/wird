/* ===== وِرد · iOS bridge (loaded only inside the iPhone app) ===== */
(function(){
  if (!window.__WIRD_NATIVE__) return;
  window.addEventListener('error', e => { try{ webkit.messageHandlers.wird.postMessage({t:'jserr', m: (e.message||'') + ' @' + (e.filename||'').split('/').pop() + ':' + (e.lineno||0)}) }catch(_){} });
  window.addEventListener('unhandledrejection', e => { try{ webkit.messageHandlers.wird.postMessage({t:'jserr', m: 'promise: ' + (e.reason && e.reason.message || e.reason)}) }catch(_){} });
  const post = (t, d) => { try{ webkit.messageHandlers.wird.postMessage(Object.assign({t}, d||{})) }catch(e){} };
  window.wirdPost = post;
  let ENV = {group:true, live:false, liveOn:false, pip:false, pipOn:false, place:'', times:null, notif:'unknown'};

  /* --- counts: native store is the source of truth --- */
  const _istAdd = istAdd;
  istAdd = function(src){ _istAdd(src); post('ist.add', {n:1}) };

  let metaT;
  function sendMeta(){
    clearTimeout(metaT);
    metaT = setTimeout(()=>{
      const f = curForm(), p = PAL[S.pal] || PAL.navy;
      const col = (c, dark) => { const v = iconVars(c, dark); return {bg1:v['--ic-bg1'], bg2:v['--ic-bg2'], bead:v['--ic-bead'], tx:v['--ic-tx'], orn:c.orn, acc:c.acc, accFg:c['acc-fg'], bg:c.bg, fg:c.fg, muted:c.muted} };
      post('ist.meta', {goal: istGoal(), formShort: f.s, formText: f.t, palette:{light: col(p.light,false), dark: col(p.dark,true)}});
    }, 250);
  }
  const _saveIst = saveIst; saveIst = function(){ _saveIst(); sendMeta() };
  const _saveS = saveS; saveS = function(){ _saveS(); sendMeta(); post('settings', {rem: S.rem}) };
  const _applyTheme = applyTheme; applyTheme = function(){ _applyTheme(); post('theme', {dark: resolvedDark()}) };
  const _kahf = markKahfRead; markKahfRead = function(){ const was = kahfDone(); _kahf(); if (!was && kahfDone()) post('kahf.done') };

  /* --- wake lock, copy, share --- */
  let wakeOn = false;
  toggleWake = function(btn){ wakeOn = !wakeOn; post('wake', {on: wakeOn}); if (btn) btn.setAttribute('aria-pressed', wakeOn); toast(wakeOn ? 'الشاشة لن تنطفئ أثناء القراءة' : 'أُلغي تثبيت الشاشة') };
  copyText = async function(txt){ post('copy', {text: txt}); return true };
  navigator.share = function(d){ post('share', {text: (d && d.text) || ''}); return Promise.resolve() };

  /* --- native → web --- */
  window.wirdNative = {
    istSync(st){
      if (!st) return;
      IST.days = st.days || {}; IST.total = st.total || 0; ls.set('ist', IST);
      if (route()==='istighfar' || route()==='home') render(true); else istPaint('init');
    },
    setTimes(t){ if (!t) return; Object.assign(T, t); ENV.times = t; for (const c of ['morning','evening']) if (counts[c].key !== cycleKey(c)){ counts[c] = {key: cycleKey(c), c:{}}; saveC() } if (!sheetOpen) render(true); else resheet() },
    setEnv(e){ Object.assign(ENV, e||{}); if (sheetOpen) resheet(); if (route()==='istighfar') render(true) },
    go(r){ if (!r) return; if (r==='settings'){ if (typeof endSplash==='function') endSplash(); setTimeout(openSheet, 400); return } location.hash = r },
    restore(data){
      try{
        const o = typeof data === 'string' ? JSON.parse(data) : data;
        if (!o || o.app !== 'wird' || !o.data) return toast('الملف ليس نسخة احتياطية من وِرد');
        Object.keys(localStorage).filter(k=>k.startsWith('wird3:')).forEach(k=>localStorage.removeItem(k));
        for (const k in o.data) localStorage.setItem(k, o.data[k]);
        const ist = o.data['wird3:ist'] ? JSON.parse(o.data['wird3:ist']) : {days:{}, total:0};
        post('ist.replace', {days: ist.days||{}, total: ist.total||0});
        setTimeout(()=>location.reload(), 300);
      }catch(err){ toast('تعذّرت قراءة الملف') }
    },
    toast(m){ toast(m) }
  };

  /* --- settings: real reminders, prayer times, backup --- */
  const fmt = h => { if (h==null) return '—'; let H = Math.floor(h), M = Math.round((h-H)*60); if (M===60){ H++; M=0 } const ap = H<12 ? 'ص' : 'م'; const h12 = ((H+11)%12)+1; return AR(h12)+':'+AR(String(M).padStart(2,'0'))+' '+ap };
  const _sheetHTML = sheetHTML;
  sheetHTML = function(){
    let h = _sheetHTML();
    const pi = h.indexOf('<div class="grp"><h4>معاينة التوقيت'); if (pi>=0){ let pj = h.indexOf('<div class="grp">', pi+10); const pk = h.indexOf('<div class="about">', pi); if (pj<0 || (pk>=0 && pk<pj)) pj = pk; if (pj>pi) h = h.slice(0,pi) + h.slice(pj) }
    h = h.replace('<p class="hint">التذكيرات للعرض فقط في هذا النموذج.</p>', ENV.notif==='denied' ? '<p class="hint">الإشعارات متوقفة لـ«وِرد». فعّلها من إعدادات الآيفون ← الإشعارات ← وِرد.</p>' : '<p class="hint">تُحسب أوقات التذكير من مواقيت الصلاة في موقعك.</p>');
    const t = ENV.times;
    const times = t ? [['الفجر',t.fajr],['الشروق',t.sunrise],['الظهر',t.dhuhr],['العصر',t.asr],['المغرب',t.maghrib],['العشاء',t.isha]] : [];
    const extra = `
  <div class="grp"><h4>مواقيت الصلاة</h4><div class="box glass">
    <div class="row"><div class="lab"><b>${ENV.place || 'الموقع'}</b><small>${ENV.locNote || 'تُحسب المواقيت من موقعك بدون إنترنت'}</small></div><button class="chip" data-nat="loc">تحديث الموقع</button></div>
    ${times.length ? `<div class="ptimes">${times.map(([n,v])=>`<div><small>${n}</small><b class="digits">${fmt(v)}</b></div>`).join('')}</div>` : ''}
  </div></div>
  <div class="grp"><h4>النسخ الاحتياطي</h4><div class="box glass">
    <div class="row"><div class="lab"><b>حفظ نسخة</b><small>العدّات والعلامات والصيغ والإعدادات في ملف واحد</small></div><button class="chip" data-nat="export">حفظ</button></div>
    <div class="row"><div class="lab"><b>استعادة نسخة</b><small>من ملف حفظته سابقاً، يستبدل البيانات الحالية</small></div><button class="chip" data-nat="import">استعادة</button></div>
  </div></div>
  ${ENV.group ? '' : '<div class="grp"><div class="box glass"><div class="row"><div class="lab"><b>الويدجت لا تقرأ العدّاد</b><small>شهادة التوقيع لا تدعم «مجموعات التطبيقات»، لذلك تبقى أرقام الويدجت صفراً. وقّع التطبيق بشهادة تدعمها.</small></div></div></div></div>'}
  `;
    return h.replace('<div class="about">', extra + '<div class="about">');
  };
  sheet.addEventListener('click', e => {
    const b = e.target.closest('[data-nat]'); if (!b) return;
    const a = b.dataset.nat;
    if (a==='loc'){ post('loc.refresh'); toast('جارٍ تحديد الموقع…') }
    if (a==='export'){ const data = {}; Object.keys(localStorage).filter(k=>k.startsWith('wird3:')).forEach(k=>data[k]=localStorage.getItem(k)); post('backup.export', {json: JSON.stringify({app:'wird', v:1, at:new Date().toISOString(), data})}) }
    if (a==='import') post('backup.import');
  });

  /* --- istighfar: real outside-the-app tools --- */
  GUIDES.at.s = ['افتح تطبيق «الاختصارات» ← اضغط + ← «إضافة إجراء» ← ابحث عن «وِرد» ← اختر «استغفر». سمِّ الاختصار «استغفر».','افتح الإعدادات ← تسهيلات الاستخدام ← اللمس ← AssistiveTouch وفعّله.','اضغط «نقرة واحدة» واختر اختصار «استغفر» من قسم الاختصارات.','حرّك الزر لأي مكان. كل نقرة عليه تضيف استغفاراً فوق أي تطبيق أو فيديو.'];
  GUIDES.back.s = ['أنشئ اختصار «استغفر» من تطبيق «الاختصارات» كما في خطوة الزر العائم.','افتح الإعدادات ← تسهيلات الاستخدام ← اللمس ← النقر على الظهر.','اختر «نقر مزدوج» أو «نقر ثلاثي» ثم اختصار «استغفر».','الآن النقر على ظهر الآيفون يضيف استغفاراً من أي مكان.'];
  const _viewIst = viewIst;
  viewIst = function(){
    let h = _viewIst();
    h = h.replace("'النافذة العائمة', 'نافذة صغيرة فوق الفيديو والتطبيقات تعرض العدد'", '');
    h = h.replace('نافذة صغيرة فوق الفيديو والتطبيقات تعرض العدد', ENV.pip ? (ENV.pipOn ? 'تعمل الآن · اضغط لإيقافها' : 'اضغط لتشغيلها، ثم اخرج من التطبيق. زر التشغيل فيها يعدّ') : 'غير متاحة في هذا الجهاز');
    h = h.replace('الجزيرة الديناميكية</b>', 'العدّاد على شاشة القفل</b>');
    h = h.replace('العدد أعلى الشاشة وزر +١ بالضغط المطوّل', ENV.liveOn ? 'يعمل الآن · اضغط لإيقافه' : (ENV.live ? 'العدد وزر +١ على شاشة القفل، وفي الجزيرة الديناميكية إن وُجدت' : 'فعّل «الأنشطة الحية» لوِرد من الإعدادات'));
    h = h.replace('نقرة واحدة فوق أي تطبيق تضيف استغفاراً', 'طريقة التفعيل خطوة بخطوة');
    h = h.replace('نقرتان على ظهر الآيفون = استغفار', 'طريقة التفعيل خطوة بخطوة');
    h = h.replace('سبعة أشكال للشاشة الرئيسية وشاشة القفل، تعدّ بنقرة', 'معاينة الأشكال وطريقة إضافتها');
    h = h.replace('<p class="hint">هذه الطرق تعمل في نسخة الآيفون. هنا تجربة تحاكي شكلها وطريقة استخدامها.</p>', '');
    return h;
  };
  function showGuide(k){ const g = GUIDES[k]; openModal(`<h3>${g.t}</h3><ol class="g-ol">${g.s.map(x=>`<li>${x}</li>`).join('')}</ol><p class="hint">قد تختلف أسماء القوائم قليلاً حسب إصدار iOS.</p><div class="m-btns"><button class="cta" data-m="cancel">فهمت</button></div>`) }
  document.addEventListener('click', e => {
    const b = e.target.closest('[data-act]'); if (!b || route()!=='istighfar') return;
    const a = b.dataset.act;
    if (!['demo-pip','demo-at','demo-island','demo-back'].includes(a)) return;
    e.stopPropagation(); e.preventDefault();
    if (a==='demo-pip'){ if (!ENV.pip) return toast('النافذة العائمة غير متاحة في هذا الجهاز'); post(ENV.pipOn ? 'pip.stop' : 'pip.start') }
    if (a==='demo-island'){ if (!ENV.live && !ENV.liveOn) return toast('فعّل «الأنشطة الحية» لوِرد من إعدادات الآيفون'); post(ENV.liveOn ? 'live.stop' : 'live.start') }
    if (a==='demo-at') showGuide('at');
    if (a==='demo-back') showGuide('back');
  }, true);
  const _openWidgets = openWidgets;
  openWidgets = function(){ _openWidgets(); const n = wg.querySelector('.wg-note'); if (n) n.textContent = 'لإضافتها: اضغط مطوّلاً على الشاشة الرئيسية ← «تعديل» ← «إضافة أداة» ← ابحث عن «وِرد» واختر الشكل والحجم. زر +١ فيها يعدّ مباشرة بدون فتح التطبيق.' };

  /* --- start --- */
  document.documentElement.classList.add('native');
  sendMeta(); post('settings', {rem: S.rem}); post('theme', {dark: resolvedDark()});
  post('ready');
})();
