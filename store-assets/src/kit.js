// Tabbb app UI kit: each screen returns the inner HTML of a .phone mockup.
const I = {
  tri: '<svg width="22" height="22" viewBox="0 0 24 24"><path d="M12 5 20 19H4Z" fill="none" stroke="#fff" stroke-width="2.6" stroke-linejoin="round"/></svg>',
  layers: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linejoin="round"><path d="M12 3 21 9l-9 6-9-6Z"/><path d="m3 14 9 6 9-6"/></svg>',
  bolt: '<svg width="22" height="22" viewBox="0 0 24 24"><path d="M13 2 5 14h6l-1 8 8-12h-6Z" fill="#fff"/></svg>',
  search: '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" stroke-width="2.6"><circle cx="10" cy="10" r="6.5"/><path d="m15 15 6 6"/></svg>',
  qr: '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" stroke-width="2.2"><path d="M3 8V3h5M16 3h5v5M21 16v5h-5M8 21H3v-5"/><rect x="7" y="7" width="4" height="4"/><rect x="13" y="13" width="4" height="4"/><path d="M13 7h4v3M7 13h3v4"/></svg>',
  sliders: '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" stroke-width="2.4"><path d="M4 6h16M4 12h16M4 18h16"/><path d="M15 3v6M8 9v6M14 15v6" stroke-width="2.6"/></svg>',
  link: '<svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" stroke-width="2.6" stroke-linecap="round"><path d="M10 14a4 4 0 0 0 5.6 0l3-3a4 4 0 0 0-5.6-5.6l-1 1"/><path d="M14 10a4 4 0 0 0-5.6 0l-3 3a4 4 0 0 0 5.6 5.6l1-1"/></svg>',
  eye: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" stroke-width="2.4"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg>',
  group: (c = '#fff', s = 26) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="${c}"><circle cx="12" cy="8" r="3.2"/><circle cx="5" cy="9.5" r="2.4"/><circle cx="19" cy="9.5" r="2.4"/><path d="M6 19c0-3.3 2.7-6 6-6s6 2.7 6 6Z"/><path d="M1 18c0-2.5 1.8-4.5 4-4.5 1 0 1.6.3 2.2.7A7 7 0 0 0 4.6 18Zm22 0c0-2.5-1.8-4.5-4-4.5-1 0-1.6.3-2.2.7A7 7 0 0 1 19.4 18Z"/></svg>`,
  home: c => `<svg width="24" height="24" viewBox="0 0 24 24" fill="${c ? '#0A0A0A' : 'none'}" stroke="currentColor" stroke-width="2.3" stroke-linejoin="round"><path d="M3 11 12 3l9 8v10h-6v-6H9v6H3Z"/></svg>`,
  receipt: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M6 3h12v18l-3-2-3 2-3-2-3 2Z"/><path d="M9 8h6M9 12h6M9 16h4"/></svg>',
  user: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-7 8-7s8 3 8 7"/></svg>',
  arrowIn: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" stroke-width="2.8"><path d="M18 6 6 18M6 9v9h9"/></svg>',
  arrowOut: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.8"><path d="M6 18 18 6M9 6h9v9"/></svg>',
  chev: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" stroke-width="3"><path d="m9 5 7 7-7 7"/></svg>',
  back: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" stroke-width="2.6"><path d="M20 12H5m6-7-7 7 7 7"/></svg>',
  dots: '<svg width="22" height="22" viewBox="0 0 24 24" fill="#0A0A0A"><circle cx="5" cy="12" r="2.2"/><circle cx="12" cy="12" r="2.2"/><circle cx="19" cy="12" r="2.2"/></svg>',
  spark: '<svg width="40" height="40" viewBox="0 0 24 24" fill="#0A0A0A"><path d="M9 3c.6 4 2 5.4 6 6-4 .6-5.4 2-6 6-.6-4-2-5.4-6-6 4-.6 5.4-2 6-6Z"/><path d="M18 2c.3 2 1 2.7 3 3-2 .3-2.7 1-3 3-.3-2-1-2.7-3-3 2-.3 2.7-1 3-3ZM18 14c.3 2 1 2.7 3 3-2 .3-2.7 1-3 3-.3-2-1-2.7-3-3 2-.3 2.7-1 3-3Z"/></svg>',
  plus: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M12 4v16M4 12h16"/></svg>',
  tick: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="4"><path d="m4 12 5 5L20 6"/></svg>',
};

const AV = {
  YO: ['#ECE6F8', '#5B4A8A'], AS: ['#F6E5E2', '#A4472F'], RA: ['#F3ECDC', '#845A10'],
  NE: ['#E6F0EA', '#2F6F52'], KA: ['#E9EFF5', '#385878'], ZO: ['#FBE3EC', '#B02A5C'],
};
const av = (k, cls = 'av') => `<div class="${cls}" style="background:${AV[k][0]};color:${AV[k][1]}">${k}</div>`;

const status = () => `<div class="status"><span>9:41</span><span class="r">
  <svg width="18" height="14" viewBox="0 0 18 14"><path d="M1 13h3V9H1Zm5 0h3V6H6Zm5 0h3V3h-3Z" fill="#0A0A0A"/></svg>
  <svg width="18" height="14" viewBox="0 0 24 18" fill="none" stroke="#0A0A0A" stroke-width="2.6"><path d="M2 6a15 15 0 0 1 20 0M5.5 9.5a10 10 0 0 1 13 0M9 13a5 5 0 0 1 6 0"/></svg>
  <span class="bat"><i></i></span></span></div>`;

const nav = on => `<div class="nav">${[['Home', I.home(on === 0)], ['Cribs', I.group(on === 1 ? '#0A0A0A' : '#6a6a6a', 26)], ['Activity', I.receipt], ['Profile', I.user]]
  .map(([n, ic], i) => `<div class="${i === on ? 'on' : ''}"><i>${ic}</i>${n}</div>`).join('')}</div>`;

const balanceCard = (hey, name, lbl, amt, fab) => `<div class="bcard"><div class="slab"></div>
  <div class="top"><div class="sm">${hey}</div><div class="big">${name}</div></div>
  <div class="bot"><div class="coins"></div><div><div class="lbl">${lbl}</div><div class="amt" data-amt>${amt}</div></div>
  <div class="fab">${fab}</div></div></div>`;

const S = {
  home: () => `${status()}<div class="body">
    <div class="hdr"><div class="logo">${I.tri}</div><h1>Tabbb</h1>${I.search}${I.qr}</div>
    ${balanceCard('Hey', 'Devang', 'You are owed:', '₹2,340.50', I.link)}
    <div class="people">
      <div class="person"><div class="av" style="background:#F1F1F4;font-size:34px;font-weight:400">+</div><b>Add</b></div>
      <div class="dash"></div>
      <div class="person">${av('AS')}<b>Asha</b><small>₹900.00</small></div>
      <div class="person">${av('RA')}<b>Ravi</b><small>₹1,499.00</small></div>
      <div class="person">${av('NE')}<b>Neha</b><small>₹3,000</small></div>
    </div>
    <div class="graff">All good<br>in the hood, bro.</div>
    <div class="act" style="margin-top:34px;background:var(--chip);border-color:var(--chip)"><div class="bub" style="background:var(--purple)">🔁</div><p><b>Netflix</b> renews in 3 days<small>Our flat · split 5 ways</small></p><em>₹129.80</em></div>
  </div>${nav(0)}`,

  cribs: () => `${status()}<div class="body">
    <div class="hdr"><div class="logo">${I.layers}</div><h1>Cribs</h1><span class="btn-pill">+ Create</span></div>
    <div class="stats">
      <div class="stat"><div class="dot" style="background:var(--lime)">${I.arrowIn}</div><div><small>To receive</small><b>₹2,340.50</b></div></div>
      <div class="stat"><div class="dot" style="background:var(--pink)">${I.arrowOut}</div><div><small>To pay</small><b>₹600.00</b></div></div>
    </div>
    <div class="sec"><div class="tri"></div><h2>Your cribs</h2><small>3 shown</small></div>
    <div class="chips"><span class="chip on">All</span><span class="chip">Owed to you</span><span class="chip">You owe</span></div>
    ${[['Our flat', '5 members · INR', 'Owed', '', ['YO', 'AS', 'RA'], '+2', '₹1,740.50', 'var(--owed)'],
       ['Goa trip', '4 members · INR', 'You owe', 'pink', ['YO', 'NE', 'KA'], '+1', '₹600.00', 'var(--owe)'],
       ['Office lunch', '6 members · INR', 'Owed', '', ['YO', 'ZO', 'AS'], '+3', '₹600.00', 'var(--owed)']]
      .map(([n, m, t, tc, st, more, v, col]) => `<div class="crib"><div class="row"><div class="ico">${I.group()}</div>
        <div><h3>${n}</h3><p>${m}</p></div><span class="tag ${tc}">${t}</span></div><hr>
        <div class="row"><div class="stack">${st.map(k => av(k, 'mini')).join('')}</div><span style="font:600 14px Space;margin-left:14px">${more}</span>
        <span class="val" style="color:${col}">${v}</span>${I.chev}</div></div>`).join('')}
  </div>${nav(1)}`,

  detail: () => `${status()}<div class="body">
    <div class="hdr"><div class="round">${I.back}</div><div style="flex:1"><h1 style="font-size:28px;line-height:1">Our flat</h1><small style="font:500 15px Space;color:var(--grey)">5 people</small></div><div class="round">${I.dots}</div></div>
    ${balanceCard('Your balance in', 'Our flat', 'You are owed:', '₹1,740.50', I.group('#0A0A0A', 30))}
    <div class="sec"><h2>Payments</h2><small>12 total</small></div>
    <span class="date">Today</span>
    <div class="exp">${av('YO')}<div class="card lime"><div class="t"><span>Groceries 🛒</span><span>₹2,450</span></div><span class="share">You lent ₹1,960</span></div></div>
    <span class="date">Yesterday</span>
    <div class="exp">${av('AS')}<div class="card"><div class="t"><span>Electricity</span><span>₹1,800</span></div><span class="share">My share ₹360</span></div></div>
    <div class="exp">${av('RA')}<div class="card"><div class="t"><span>Wi-Fi bill</span><span>₹1,499</span></div><span class="share">My share ₹299.80</span></div></div>
  </div><div class="addfab">${I.plus} Add</div>`,

  add: () => `${S.detail().replace('<div class="addfab">', '<div class="addfab" style="display:none">')}<div class="scrim"></div>
    <div class="sheet"><div class="grab"></div><h2>Add expense</h2>
      <div class="field"><small>Amount</small><div class="amount">₹2,450<span>.00</span></div></div>
      <div class="field"><small>What was it for?</small><div class="input">Groceries 🛒</div></div>
      <div class="field"><small>Split equally with 4</small></div>
      <div class="split">${[['YO', 'You'], ['AS', 'Asha'], ['RA', 'Ravi'], ['NE', 'Neha']].map(([k, n]) =>
        `<div class="ln">${av(k)}<b>${n}</b><em>₹612.50</em><span class="check">${I.tick}</span></div>`).join('')}</div>
      <div class="primary">Add expense</div></div>`,

  settle: () => `${S.cribs()}<div class="scrim"></div>
    <div class="sheet"><div class="grab"></div><h2>Settle up</h2>
      <p style="font:500 16px Space;color:#5F5F5B;margin:-6px 0 18px">The fewest moves to make <b style="color:var(--ink)">Goa trip</b> square:</p>
      <div class="move">${av('YO')}<div class="arrow"><span>₹600</span></div>${av('NE')}</div>
      <div class="move">${av('KA')}<div class="arrow"><span>₹450</span></div>${av('NE')}</div>
      <div style="display:flex;gap:10px;align-items:center;background:var(--chip);border-radius:20px;padding:12px 14px;margin:6px 0 18px;font:500 14px Space">
        <span style="font-size:20px">⚡</span>2 transfers instead of 6. That's it.</div>
      <div class="primary lime">Record my transfer</div></div>`,

  activity: () => `${status()}<div class="body">
    <div class="hdr"><div class="logo">${I.bolt}</div><h1>Activity</h1>${I.sliders}</div>
    <div class="banner">${I.spark}<span>Everything your groups have been up to.</span></div>
    <div class="sec"><div class="tri"></div><h2>Latest updates</h2></div>
    ${[['var(--lime)', '🛒', '<b>You</b> added <b>Groceries</b> in Our flat', '2m ago', '₹2,450'],
       ['var(--pink)', '✓', '<b>Kabir</b> settled up with <b>Neha</b>', '1h ago', '₹450'],
       ['#fff', '⚡', '<b>Asha</b> added <b>Electricity</b> in Our flat', 'Yesterday', '₹1,800'],
       ['var(--purple)', '👋', '<b>Zoya</b> joined <b>Office lunch</b>', 'Yesterday', ''],
       ['#fff', '🔁', '<b>Netflix</b> repeats monthly in Our flat', '2 days ago', '₹649']]
      .map(([c, e, t, w, a]) => `<div class="act"><div class="bub" style="background:${c}">${e}</div><p>${t}<small>${w}</small></p><em>${a}</em></div>`).join('')}
  </div>${nav(2)}`,
};

function phone(name, extraStyle = '') {
  return `<div class="phone" style="${extraStyle}"><div class="screen">${S[name]()}</div></div>`;
}
