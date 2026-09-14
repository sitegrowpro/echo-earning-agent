// PHONE — the Fears-to-Fathom signature system: real-time texts that start cozy
// and turn into the threat vector. Threads, scripted beats, reply choices, calls.
export class Phone {
  constructor(audio, story) {
    this.audio = audio; this.story = story;
    this.threads = { mom: [], mason: [], unknown: [] };
    this.active = 'mom';
    this.visible = false;
    this.unread = { mom: 0, mason: 0, unknown: 0 };
    this.el = document.getElementById('phone');
    this.msgs = document.getElementById('phone-messages');
    this.replies = document.getElementById('phone-replies');
    document.querySelectorAll('#phone-threads button').forEach((b) => {
      b.onclick = () => { this.audio.uiClick(); this.show(b.dataset.thread); };
    });
  }
  toggle(force) {
    this.visible = force !== undefined ? force : !this.visible;
    this.el.classList.toggle('hidden', !this.visible);
    if (this.visible) { this.render(); this.unread[this.active] = 0; }
    return this.visible;
  }
  show(t) { this.active = t; this.unread[t] = 0; this.render(); }
  render() {
    document.querySelectorAll('#phone-threads button').forEach((b) =>
      b.classList.toggle('active', b.dataset.thread === this.active));
    this.msgs.innerHTML = '';
    for (const m of this.threads[this.active]) {
      const d = document.createElement('div');
      d.className = 'msg ' + (m.me ? 'me' : m.sys ? 'sys' : 'them');
      d.textContent = m.text;
      this.msgs.appendChild(d);
    }
    this.msgs.scrollTop = this.msgs.scrollHeight;
  }
  setReplies(opts) { // [{text, cb}]
    this.replies.innerHTML = '';
    for (const o of opts) {
      const b = document.createElement('button');
      b.textContent = o.text;
      b.onclick = () => { this.audio.uiClick(); this.replies.innerHTML = ''; o.cb(); };
      this.replies.appendChild(b);
    }
  }
  // scripted incoming sequence with delays; returns promise
  async incoming(thread, texts, gap = 1600) {
    if (thread === 'unknown') document.getElementById('tab-unknown').classList.remove('hidden');
    for (const t of texts) {
      await this.wait(gap * (0.7 + Math.random() * 0.6));
      this.threads[thread].push({ text: t });
      this.audio.textDing();
      if (!this.visible || this.active !== thread) {
        this.unread[thread]++;
        this.story.toast(`✉ ${thread === 'mom' ? 'Mom' : thread === 'mason' ? 'Mason' : 'Unknown number'}`);
      } else this.render();
      this.story.onPhone(thread, t);
    }
  }
  send(thread, text) {
    this.threads[thread].push({ text, me: true });
    if (this.visible && this.active === thread) this.render();
  }
  sys(text) {
    this.threads[this.active].push({ text, sys: true });
    if (this.visible) this.render();
  }
  wait(ms) { return new Promise((r) => setTimeout(r, ms)); }
  setClock(str) { document.getElementById('phone-clock').textContent = str; }
}
