// STORY — the narrative state machine. 7 chapters (~60 min), objectives, phone
// scripts, scares, power/door/light logic, hiding, the 911 wait, 4 endings.
// Chapters: 0 Arrival · 1 Chores · 2 Dinner & Static · 3 Knock Knock ·
//            4 Blackout · 5 He's Inside · 6 Run.
import { CFG } from './config.js';
import { HIDE, PERCHES } from './world.js';

export const NOTES = {
  mail: { title: 'Letter — County Sheriff', body: `NOTICE TO RESIDENTS OF HOLLOW CREEK

Over the past two weeks our office has received multiple reports of a man seen standing at the edge of properties after dark, watching homes.

He has not approached anyone. He leaves when spoken to.

Lock your doors. Report anything unusual.

— Sheriff D. Calloway` },
  fridge: { title: 'Fridge note — Mom', body: `Alex!!

Working late again, home around midnight. Mason's mom said he can come over if you want company — but HOMEWORK FIRST young man.

There's leftover pasta, 2 minutes in the microwave. Don't just eat cereal.

Love you. Lock up. 🔒
— Mom` },
  photo: { title: 'Framed photo (back)', body: `In faded pen:

"Summer '19 — Alex, 11, refusing to smile. Dad burning burgers. Perfect day."

Something about the photo's glass catches the dark behind you. For a second you think someone is standing in the hallway.

It's just your reflection. Probably.` },
  doodle: { title: 'Homework margin', body: `Algebra II — page 47, half finished.

In the margin you've doodled the house. And next to the house, a tall figure with no face.

You don't remember drawing that.` },
  parents: { title: 'Note on parents’ bed — Dad', body: `M —

Called the locksmith about the back window latch again. Don't forget: it DOESN'T lock. I've told you three times. Anyone could get in through there.

If I'm still at the site when you read this, wedge a chair under it.

— D.` },
  bath: { title: 'Bathroom cabinet card', body: `A dentist appointment card. On the back, in your little brother's handwriting from before he moved out:

"alex if the man comes back hide under the bed like we practiced. dont let him hear you breathe"

Your brother moved out two years ago. He never told you about any man.` },
  manual: { title: 'Fuse box manual', body: `HOLLOW CREEK ELECTRIC — Model FB-3

"If all breakers trip at once, flip each switch LEFT then RIGHT, one at a time. Wait for the click.

WARNING: simultaneous trips usually mean a surge... or manual interference at the meter."

Someone has circled "manual interference" in red.` },
  masonNote: { title: 'Note slipped under the door', body: `In Mason's handwriting, shaky:

"dude whoever knocked earlier it was NOT funny. i saw him standing by your window and he just STARED. i'm going home. do NOT open the door tonight. call me"

The ink is smeared, like it was written fast.` },
};

const CHAPTERS = [
  { kicker: '8:12 PM', name: 'Arrival', sub: 'Home alone. One night. What could go wrong?' },
  { kicker: '8:40 PM', name: 'Chores', sub: 'Homework first, young man.' },
  { kicker: '9:35 PM', name: 'Dinner & Static', sub: 'Something on the news. Something outside.' },
  { kicker: '10:20 PM', name: 'Knock Knock', sub: 'Do NOT open the door.' },
  { kicker: '10:58 PM', name: 'Blackout', sub: 'The dark is full of sounds.' },
  { kicker: '11:24 PM', name: 'He’s Inside', sub: 'Don’t run. Don’t breathe. Don’t shine light.' },
  { kicker: '11:52 PM', name: 'Run', sub: 'Whatever you do — don’t let him touch you.' },
];

export class Story {
  constructor(deps) {
    this.d = deps; // {audio, world, enemy, player, scene}
    this.ui = null; this.phone = null;
    this.reset();
  }
  reset() {
    this.chapter = -1;
    this.flags = {};
    this.objectives = [];
    this.items = { flash: false, flashOn: false, battery: 100, batteries: 0, parentsKey: false, carKeys: false, food: null, trash: false };
    this.notesFound = [];
    this.choices = [];
    this.clockMin = 20 * 60 + 12;
    this.startTime = Date.now();
    this.spotted = 0; this.finished = false;
    this.scriptToken = 0;
    this.micro = { state: 'idle', t: 0 };
    this.newsT = 0; this.newsSeg = 0;
    this.policeT = -1; this.policeLight = null; this.policePhase = 0;
    this.strangerOut = false;
    this.homeworkPages = 0;
    this.fuseN = 0;
    this.flickerT = 0; this.flickerRoom = null;
    this.dialogOpen = false; this.noteOpen = false; this.peepOpen = false; this.callOpen = false;
    this.hideWarned = false;
  }
  get flashOn() { return this.items.flashOn && this.items.flash && this.items.battery > 0; }
  uiBusy() { return this.dialogOpen || this.noteOpen || this.peepOpen || this.callOpen || this.finished; }

  // ---------- helpers ----------
  toast(t) { this.ui.toast(t); }
  sub(t, dur = 4) { this.ui.subtitle(t, dur); }
  obj(id, text) { if (!this.objectives.find((o) => o.id === id)) this.objectives.push({ id, text, done: false }); this.renderObj(); }
  done(id) {
    const o = this.objectives.find((o) => o.id === id);
    if (!o || o.done) return;
    o.done = true; this.d.audio.pickup(); this.renderObj();
    this.toast('✓ ' + o.text);
    this.checkAdvance();
  }
  isDone(id) { const o = this.objectives.find((o) => o.id === id); return !!(o && o.done); }
  renderObj() { this.ui.objectives(this.objectives); }
  say(sp, text, opts) { // dialog choices UI
    this.dialogOpen = true; this.d.player.frozen = true;
    this.ui.dialog(sp, text, (opts || []).map((o) => ({ text: o.text, cb: () => { this.dialogOpen = false; this.d.player.frozen = false; this.ui.closeDialog(); o.cb(); } })));
  }
  read(id) {
    const n = NOTES[id]; if (!n) return;
    if (!this.notesFound.includes(id)) { this.notesFound.push(id); this.toast(`📄 Note (${this.notesFound.length}/8)`); }
    this.noteOpen = true; this.d.player.frozen = true;
    this.d.audio.uiClick();
    this.ui.note(n.title, n.body);
  }
  closeNote() { this.noteOpen = false; this.d.player.frozen = false; this.ui.closeNote(); }
  clockStr() {
    const h24 = Math.floor(this.clockMin / 60) % 24, m = Math.floor(this.clockMin % 60);
    const h = ((h24 + 11) % 12) + 1, ap = h24 >= 12 ? 'PM' : 'AM';
    return `${h}:${String(m).padStart(2, '0')} ${ap}`;
  }
  tickClock(dt) {
    this.clockMin += dt / 4; // 1 game-min per 4 real-sec
    const s = this.clockStr();
    this.ui.vhs(s); this.phone.setClock(s);
  }

  // ---------- game flow ----------
  newGame() {
    this.reset();
    this.d.player.pos.set(0, CFG.eye, 7.4); this.d.player.setLook(Math.PI, 0);
    this.gotoChapter(0);
  }
  serialize() {
    return {
      chapter: this.chapter, flags: this.flags, items: this.items, notesFound: this.notesFound,
      choices: this.choices, clockMin: this.clockMin, homeworkPages: this.homeworkPages,
      objectivesDone: this.objectives.filter((o) => o.done).map((o) => o.id),
      pos: [this.d.player.pos.x, this.d.player.pos.z], yaw: this.d.player.yaw,
    };
  }
  load(s) {
    this.reset();
    Object.assign(this.flags, s.flags || {});
    Object.assign(this.items, s.items || {});
    this.notesFound = s.notesFound || []; this.choices = s.choices || [];
    this.clockMin = s.clockMin ?? this.clockMin; this.homeworkPages = s.homeworkPages || 0;
    this.d.player.pos.set(s.pos?.[0] ?? 0, CFG.eye, s.pos?.[1] ?? 7.4);
    this.d.player.setLook(s.yaw ?? Math.PI, 0);
    this.gotoChapter(s.chapter ?? 0);
    for (const id of s.objectivesDone || []) { const o = this.objectives.find((o) => o.id === id); if (o) o.done = true; }
    this.renderObj();
  }
  gotoChapter(n) {
    this.scriptToken++;
    this.chapter = n;
    const c = CHAPTERS[n];
    this.ui.chapterCard(c.kicker, `Chapter ${n}: ${c.name}`, c.sub);
    this.objectives = [];
    this['setup' + n]();
    this.renderObj();
    this.ui.autosave();
  }
  checkAdvance() {
    const D = (id) => this.isDone(id);
    if (this.chapter === 0 && D('lock')) this.gotoChapter(1);
    else if (this.chapter === 1 && D('groceries') && D('trash') && D('thermo') && D('homework')) this.gotoChapter(2);
    else if (this.chapter === 2 && D('dinner') && D('news') && D('mason')) this.gotoChapter(3);
    else if (this.chapter === 3 && D('peep') && D('door') && D('momreply')) this.gotoChapter(4);
    else if (this.chapter === 4 && D('flash') && D('fuse')) this.gotoChapter(5);
    else if (this.chapter === 5 && D('key') && D('carkeys')) this.gotoChapter(6);
  }

  // ================= CHAPTER SETUPS =================
  setup0() {
    this.obj('lock', 'Get inside and lock the front door');
    this.sub('Rain. An empty house. Mom’s working late — again.', 5);
    const t = this.scriptToken;
    (async () => {
      await this.phone.wait(2500); if (t !== this.scriptToken) return;
      await this.phone.incoming('mom', [
        'Hey sweetie!! Working late, home around midnight 😘',
        'Mason can come over if you want. But HOMEWORK FIRST.',
        'Leftover pasta in the fridge. Lock the doors!!',
      ]);
      await this.phone.wait(6000); if (t !== this.scriptToken) return;
      await this.phone.incoming('mason', ['yo', 'your mom said i can come over??', 'say the word and im bringing the horror dvds lol']);
      this.phone.setReplies([
        { text: '“Come over! Bring the DVDs.”', cb: () => this.replyMasonInvite(true) },
        { text: '“Not tonight, man. Rain check?”', cb: () => this.replyMasonInvite(false) },
      ]);
    })();
  }
  replyMasonInvite(yes) {
    this.phone.send('mason', yes ? 'Come over! Bring the DVDs.' : 'Not tonight, man. Rain check?');
    this.flags.invitedMason = yes;
    this.choices.push(yes ? 'Invited Mason over' : 'Told Mason not to come');
    this.phone.incoming('mason', yes
      ? ['LETS GOOO', 'leaving in 10, gotta “borrow” my sisters umbrella 😭']
      : ['booo', 'fineee. text me if you get scared of the dark 😘']);
  }

  setup1() {
    this.obj('groceries', 'Put the groceries in the fridge');
    this.obj('trash', 'Take the trash out to the bin');
    this.obj('thermo', 'Turn the thermostat down (it’s roasting)');
    this.obj('homework', 'Do your homework at the desk (3 pages)');
    this.sub('The house ticks and settles. It always sounds bigger in the rain.', 5);
    const t = this.scriptToken;
    (async () => {
      await this.phone.wait(20000); if (t !== this.scriptToken) return;
      await this.phone.incoming('mom', ['How’s the homework going young man 👀']);
      this.phone.setReplies([
        { text: '“Almost done, promise.”', cb: () => { this.phone.send('mom', 'Almost done, promise.'); } },
        { text: '“Haven’t started lol”', cb: () => { this.phone.send('mom', 'Haven’t started lol'); this.phone.incoming('mom', ['ALEX. 😤']); } },
      ]);
      // mom calls once — cozy misdirect
      await this.phone.wait(25000); if (t !== this.scriptToken || this.chapter !== 1) return;
      this.callMom();
    })();
  }
  callMom() {
    this.callOpen = true; this.d.player.frozen = true;
    this.d.audio.phoneBuzz();
    this.ui.call('Mom 📞', () => {
      this.callOpen = false; this.d.player.frozen = false; this.ui.closeCall();
      this.d.audio.blip(440, 0.4, 'sine', 0.1, 100);
      this.sub('MOM: “Just checking on my boy. Doors locked? …Good. I love you. Be good.”', 6);
    }, () => {
      this.callOpen = false; this.d.player.frozen = false; this.ui.closeCall();
      this.phone.incoming('mom', ['Wow. Declining your own mother. 😒', 'Love you anyway.']);
    });
  }

  setup2() {
    this.obj('dinner', 'Heat the pasta and eat it on the couch');
    this.obj('news', 'Watch TV until the news is over');
    this.obj('mason', 'Reply to Mason');
    this.sub('Your stomach growls. The fridge hums. Outside, the rain gets louder.', 5);
    const t = this.scriptToken;
    (async () => {
      await this.phone.wait(15000); if (t !== this.scriptToken) return;
      if (this.flags.invitedMason) {
        await this.phone.incoming('mason', ['dude its POURING', 'mom wont let me out in this 😭', 'tomorrow for sure']);
        this.flags.invitedMason = false; this.flags.masonBailed = true;
      } else {
        await this.phone.incoming('mason', ['btw have you seen the news??', 'theres some creep going around our neighborhood', 'prob fake but lock ur doors lol']);
      }
      this.phone.setReplies([
        { text: '“lol it’s just rain. chill.”', cb: () => { this.phone.send('mason', 'lol it’s just rain. chill.'); this.phone.incoming('mason', ['if u die in a horror movie im saying i told u so']); this.done('mason'); } },
        { text: '“Wait, what?? Tell me.”', cb: () => { this.phone.send('mason', 'Wait, what?? Tell me.'); this.phone.incoming('mason', ['some tall guy just STANDS in peoples yards at night', 'cops got like 5 calls. he never does anything tho. just watches 👀']); this.done('mason'); } },
      ]);
    })();
  }

  setup3() {
    this.obj('peep', 'Look through the peephole');
    this.obj('door', 'Deal with whoever is at the door (DO NOT OPEN IT)');
    this.obj('momreply', 'Reply to Mom');
    const t = this.scriptToken;
    (async () => {
      await this.phone.wait(9000); if (t !== this.scriptToken) return;
      // rain stops. silence. then knocking.
      this.d.audio.stopRain(); this.ui.rain(false);
      this.sub('The rain stops. The house goes very, very quiet.', 4);
      await this.phone.wait(5000); if (t !== this.scriptToken) return;
      this.knockSequence();
    })();
  }
  knockSequence() {
    const t = this.scriptToken;
    const W = this.d.world, E = this.d.enemy;
    (async () => {
      this.d.audio.knock(3, false);
      E.perch(PERCHES.porch); this.strangerOut = 'porch';
      this.sub('Knocking. Three slow knocks. Nobody texts first at 10 PM.', 5);
      this.toast('🚪 Someone is at the front door');
      await this.phone.wait(20000); if (t !== this.scriptToken) return;
      if (!this.isDone('peep')) {
        this.d.audio.knock(3, true);
        this.sub('Again. Heavier this time.', 4);
      }
      await this.phone.wait(25000); if (t !== this.scriptToken) return;
      if (!this.isDone('door')) {
        // stranger speaks through the door
        this.d.audio.knock(2, true);
        this.say('??? (through the door)', '“…hey. Hey, kid. My car died down the road. Can I… can I use your phone? It’ll just take a second.”', [
          { text: '“My parents are home. Go away.” (lie)', cb: () => this.strangerTalk('lie') },
          { text: '“…Who are you? How do you know I’m a kid?”', cb: () => this.strangerTalk('ask') },
          { text: '(Say nothing. Step away from the door.)', cb: () => this.strangerTalk('silent') },
        ]);
      }
    })();
  }
  strangerTalk(how) {
    const E = this.d.enemy, A = this.d.audio;
    this.choices.push('Stranger talk: ' + how);
    if (how === 'lie') {
      this.say('???', '“…No, they’re not. Their car’s gone. I watched them leave.”', [
        { text: '(Back away. Say nothing more.)', cb: () => this.afterStranger() },
      ]);
      E.aggression += 1;
    } else if (how === 'ask') {
      A.knock(1, true);
      this.say('???', '“I know a lot of things, Alex.”', [
        { text: '(He knows your name. Back away.)', cb: () => this.afterStranger() },
      ]);
      E.aggression += 1;
    } else {
      A.knock(2, false);
      this.sub('Silence. Then, very quietly: “…okay. Okay. I’ll come back later, then.”', 6);
      this.afterStranger();
    }
  }
  afterStranger() {
    const t = this.scriptToken, E = this.d.enemy;
    this.done('door');
    E.vanish(); this.strangerOut = false;
    (async () => {
      await this.phone.wait(7000); if (t !== this.scriptToken) return;
      this.d.audio.sting();
      await this.phone.incoming('mom', [
        'ALEX. Look at this. NOW.',
        '📷 [photo attached: your house, from the street. A TALL FIGURE stands under the streetlamp, facing your window.]',
        'A neighbor just sent me this!!! There is a MAN outside our house',
        'Lock EVERYTHING. Do NOT open the door for ANYONE. I’m calling the police.',
      ], 1400);
      this.phone.setReplies([
        { text: '“Someone knocked. I didn’t open it.”', cb: () => { this.phone.send('mom', 'Someone knocked. I didn’t open it.'); this.phone.incoming('mom', ['GOOD. Stay away from the windows. Police are on the way. I love you.']); this.done('momreply'); } },
        { text: '“It’s probably nothing, Mom.”', cb: () => { this.phone.send('mom', 'It’s probably nothing, Mom.'); this.phone.incoming('mom', ['ALEX. This is NOT nothing. STAY AWAY FROM THE WINDOWS.']); this.done('momreply'); } },
      ]);
      // Mason's note slides under the door
      this.flags.masonNote = true;
      this.toast('📄 Something slides under the front door…');
    })();
  }

  setup4() {
    this.obj('flash', 'Find the flashlight (utility room shelf?)');
    this.obj('fuse', 'Reset the fuse box — 3 breakers');
    const t = this.scriptToken, W = this.d.world, A = this.d.audio;
    (async () => {
      await this.phone.wait(6000); if (t !== this.scriptToken) return;
      A.powerDown(); W.setPower(false);
      this.sub('The lights die. The fridge sighs into silence. Only the rain\'s echo remains.', 5);
      this.toast('⚡ POWER OUT');
      A.knock(1, true); // the meter box outside...?
      await this.phone.wait(12000); if (t !== this.scriptToken) return;
      await this.phone.incoming('unknown', ['the dark suits this house', 'i cut the lights so i could see you better'], 2500);
      // breathing call
      await this.phone.wait(8000); if (t !== this.scriptToken || this.chapter !== 4) return;
      this.callOpen = true; this.d.player.frozen = true;
      A.phoneBuzz();
      this.ui.call('Unknown number', () => {
        this.callOpen = false; this.d.player.frozen = false; this.ui.closeCall();
        this.sub('…breathing. Slow. Close. Then a click. Then your own porch creak, through the phone.', 7);
        A.sting(); this.choices.push('Answered the unknown call');
      }, () => {
        this.callOpen = false; this.d.player.frozen = false; this.ui.closeCall();
        this.phone.incoming('unknown', ['rude. ill just talk to you in person']);
        this.choices.push('Declined the unknown call');
      });
    })();
  }

  setup5() {
    this.obj('key', 'Find the parents’ room key (kitchen drawer?)');
    this.obj('carkeys', 'Get the CAR KEYS from the parents’ room');
    const t = this.scriptToken, W = this.d.world, A = this.d.audio, E = this.d.enemy;
    (async () => {
      await this.phone.wait(2500); if (t !== this.scriptToken) return;
      A.glassBreak();
      this.sub('GLASS. From the back of the house. The parents’ window — the one that never locked.', 6);
      this.toast('🪟 Something broke the back window');
      E.aggression += 1;
      await this.phone.wait(9000); if (t !== this.scriptToken) return;
      E.setVisible(true); E.place(1.5, -4.5, 0); E.state = 'patrol';
      this.sub('Floorboards. Slow footsteps. He is INSIDE the house.', 6);
      this.toast('🔦 Turn OFF your flashlight. Crouch. Hide under the BED or in a CLOSET.');
      this.phone.incoming('mom', ['Police are 10 minutes out. HIDE. Do not move. Do not make a sound. I love you so much.']);
    })();
  }

  setup6() {
    this.obj('escA', '🏃 Unlock the front door & run to the NEIGHBOR’S porch');
    this.obj('escB', '🪟 Climb out your BEDROOM WINDOW & reach the STREET');
    this.obj('escC', '📞 Call 911 on your phone, then HIDE until police arrive');
    this.d.enemy.aggression += 1;
    this.d.enemy.speedMul = 1.12;
    this.sub('Car keys in your fist. Three ways out. Pick one and COMMIT.', 6);
    this.phone.setReplies([{ text: '📞 CALL 911 NOW', cb: () => this.call911() }]);
    this.phone.show('mom');
    this.toast('📞 Open your phone (TAB) to call 911 — or RUN.');
  }
  call911() {
    if (this.chapter !== 6 || this.policeT >= 0) return;
    this.callOpen = true; this.d.player.frozen = true;
    this.d.audio.phoneBuzz();
    this.ui.call('911', () => {
      this.callOpen = false; this.d.player.frozen = false; this.ui.closeCall();
      this.sub('911: “Stay on the line. Officers are en route. Hide somewhere with a LOCK — and stay QUIET.”', 7);
      this.policeT = 0;
      this.toast('🚔 Police incoming. HIDE and stay quiet.');
      this.choices.push('Called 911');
    }, () => {
      this.callOpen = false; this.d.player.frozen = false; this.ui.closeCall();
      this.phone.setReplies([{ text: '📞 CALL 911 NOW', cb: () => this.call911() }]);
    });
  }

  // ---------- per-frame ----------
  update(dt) {
    this.tickClock(dt);
    const W = this.d.world, A = this.d.audio, P = this.d.player, E = this.d.enemy;

    // flashlight battery
    if (this.flashOn) {
      this.items.battery -= CFG.flashDrain * 100 * dt;
      if (this.items.battery <= 0) { this.items.battery = 0; this.items.flashOn = false; this.toast('🔦 Battery dead. Find batteries (kitchen drawer).'); A.blip(200, 0.2, 'square', 0.1, -100); }
    }
    // microwave
    if (this.micro.state === 'running') {
      this.micro.t -= dt;
      W.microLight.intensity = 2 + Math.sin(performance.now() * 0.02) * 1;
      if (this.micro.t <= 0) {
        this.micro.state = 'done'; W.microLight.intensity = 0;
        A.microwaveBeep(true); P.noise = Math.min(100, P.noise + 25);
        this.toast('🔔 The microwave beeps. (That was LOUD.)');
      }
    }
    // TV news progress (must be sitting + TV on)
    if (this.chapter === 2 && this.d.world.tvOn && P.sitting && !this.isDone('news')) {
      this.newsT += dt;
      const segs = [
        [2, '📺 “…police are asking Hollow Creek residents to lock their doors tonight…”'],
        [45, '📺 “…five separate calls about a tall figure standing in yards, watching homes…”'],
        [90, '📺 “…officials say he leaves when approached. He has never— [STATIC] —he is never gone…”'],
      ];
      if (this.newsSeg < segs.length && this.newsT >= segs[this.newsSeg][0]) {
        this.sub(segs[this.newsSeg][1], 6); A.staticBurst(); this.newsSeg++;
      }
      if (this.newsT >= 130) { this.done('news'); this.sub('📺 “…we’ll be right back after—” The screen cuts to static. The house feels colder.', 6); }
    }
    // 911 wait
    if (this.policeT >= 0 && !this.finished) {
      this.policeT += dt;
      if (this.policeT > 120 && !this.policeLight) {
        A.siren();
        this.policeLight = new THREE.PointLight(0xff2222, 40, 30);
        this.policeLight.position.set(0, 3, 10); this.d.scene.add(this.policeLight);
        this.sub('SIRENS. Red and blue wash the windows. Just a little longer—', 6);
      }
      if (this.policeLight) {
        this.policePhase += dt * 6;
        this.policeLight.color.setHex(Math.sin(this.policePhase) > 0 ? 0xff2222 : 0x2244ff);
      }
      if (this.policeT >= CFG.times.policeWait) {
        this.sub('“POLICE! SHOW ME YOUR HANDS— …Clear! Kid? KID, YOU’RE SAFE NOW.”', 7);
        this.finish('C');
      }
    }
    // heartbeat when hunted / hiding near enemy
    const hunted = (E.state === 'chase' || E.state === 'investigate');
    const nearHidden = P.hidden && Math.hypot(P.pos.x - E.pos.x, P.pos.z - E.pos.z) < 5 && E.state !== 'dormant' && E.state !== 'gone' && E.state !== 'perch';
    A.setHeart(hunted || nearHidden, E.state === 'chase');
    // light flicker events
    if (this.flickerT > 0 && this.flickerRoom) {
      this.flickerT -= dt;
      const r = W.roomLights[this.flickerRoom];
      if (r) for (const l of r.lights) l.visible = W.power && r.on && Math.random() > 0.5;
      if (this.flickerT <= 0) W.applyLights();
    }
    // mirror scare trigger (bathroom, ch4 first entry)
    // (handled in onRoom)
    // enemy proximity whispers while hidden
    if (nearHidden && !this._whispT) this._whispT = 0;
    if (nearHidden) {
      this._whispT += dt;
      if (this._whispT > 9) {
        this._whispT = 0;
        this.sub('Floorboards inches away. Breathing. “…I can hear your little heart, Alex…”', 5);
      }
    }
    // rain restarts in ch5 (atmosphere)
    if (this.chapter >= 5 && !this._rain2) { this._rain2 = true; this.ui.rain(true); A.startRain(); }
  }

  onRoom(room) {
    const W = this.d.world, A = this.d.audio;
    this.ui.roomToast(W.roomName(room));
    if (room === 'bath' && this.chapter === 4 && !this.flags.mirror) {
      this.flags.mirror = true;
      this.flicker('bath', 2.5);
      A.sting();
      this.sub('On the fogged mirror, finger-written from the INSIDE of the glass: “DON’T LET HIM IN.”', 7);
    }
    if (room === 'parents' && this.chapter >= 5 && !this.flags.parEnter) {
      this.flags.parEnter = true;
      this.sub('The back window gapes open. Glass on the carpet. Curtains breathing in the wind.', 6);
    }
  }
  flicker(room, dur) { this.flickerRoom = room; this.flickerT = dur; }
  onSpotted() {
    this.spotted++;
    this.d.audio.sting();
    this.ui.flash();
    this.sub('HE SEES YOU. R U N .', 3);
  }
  onPhone() { /* hook for future badge sfx */ }

  // ---------- doors ----------
  toggleDoor(id) {
    const W = this.d.world, A = this.d.audio, P = this.d.player;
    const d = W.doors.get(id);
    if (!d) return;
    if (id === 'parents' && d.locked) {
      if (this.items.parentsKey) {
        d.locked = false; this.flags.parentsOpen = true;
        A.pickup(); this.toast('🔑 The key turns. The parents’ room sighs open…');
      } else { A.locked(); this.sub('Locked. Mom and Dad always lock it. (The key must be around here somewhere…)', 4); return; }
    }
    if (id === 'front') {
      // prologue: engaging the deadbolt
      if (this.chapter === 0 && !this.flags.deadbolt) {
        this.flags.deadbolt = true; A.doorShut(); this.done('lock');
        this.sub('Deadbolt ON. The house seals itself around you like a held breath.', 4);
        return;
      }
      // ch3: opening = death
      if (this.chapter === 3 && this.strangerOut && !d.open) {
        d.open = true; d.target = d.swing; A.doorCreak(true);
        this.ui.jumpscare(() => this.finish('D', 'You opened the door.'));
        return;
      }
      // ch6 escape A: deadbolt must be thrown first
      if (this.chapter === 6 && this.flags.deadbolt && !this.flags.deadboltOff && !d.open) {
        this.flags.deadboltOff = true; A.doorShut(); P.noise = 100;
        this.toast('🔓 Deadbolt OFF. RUN TO THE NEIGHBOR’S PORCH.');
        this.sub('The deadbolt CLACKS. Behind you, something stands up very fast.', 4);
        if (this.d.enemy.state === 'patrol' || this.d.enemy.state === 'search') { this.d.enemy.state = 'investigate'; this.d.enemy.target = { x: 0, z: 5 }; }
        return;
      }
    }
    d.open = !d.open; d.target = d.open ? d.swing : 0;
    if (d.open) A.doorCreak(true); else { A.doorCreak(false); setTimeout(() => A.doorShut(), 450); }
    P.noise = Math.min(100, P.noise + 18);
  }

  // ---------- flashlight ----------
  toggleFlash() {
    if (!this.items.flash) { this.toast('🔦 You don’t have a flashlight yet.'); return; }
    if (this.items.battery <= 0) { this.toast('🔦 Battery dead — find batteries (kitchen drawer).'); return; }
    this.items.flashOn = !this.items.flashOn;
    this.d.audio.uiClick();
    if (this.items.flashOn && this.d.player.hidden) this.toast('⚠️ Light ON while hiding = he WILL see you. Press F to kill it.');
  }

  // ---------- hiding / sitting ----------
  hide(where) {
    const P = this.d.player;
    if (P.hidden === where) { // exit
      P.hidden = null; P.frozen = false;
      this.d.audio.doorCreak(false);
      if (where === 'bed') { P.pos.set(-6.4, CFG.eye, -3.0); P.setLook(0.4, 0); }
      if (where === 'closet') { P.pos.set(-3.6, CFG.eye, -2.0); P.setLook(-1.2, 0); }
      if (where === 'pcloset') { P.pos.set(2.2, CFG.eye, -2.0); P.setLook(1.2, 0); }
      return;
    }
    P.hidden = where; P.frozen = true;
    const h = HIDE[where];
    P.lookAt(h.pos, h.look);
    this.d.audio.doorCreak(true);
    this.ui.flashHide(where === 'bed' ? 'Under the bed. Don’t move. Don’t breathe.' : 'Inside the closet. Darkness is your only friend.');
    if (this.flashOn && !this.hideWarned) { this.hideWarned = true; this.toast('⚠️ YOUR FLASHLIGHT IS ON. Press F. NOW.'); }
  }
  sitToggle() {
    const P = this.d.player;
    if (P.sitting) { P.sitting = false; P.frozen = false; P.pos.set(-2, CFG.eye, 4.15); P.setLook(Math.PI, 0); }
    else {
      P.sitting = true; P.frozen = true;
      P.lookAt(HIDE.couch.pos, HIDE.couch.look);
      this.toast('📺 Sitting. Press E on the couch to stand.');
    }
  }

  // ---------- peephole ----------
  peep() {
    const E = this.d.enemy;
    this.peepOpen = true; this.d.player.frozen = true;
    let html;
    if (this.chapter === 3 && this.strangerOut) {
      html = '<div style="font-size:90px">🧍</div><div>A tall man. Too close to the door.<br/>He is looking DIRECTLY at the peephole.<br/><br/>He smiles.</div>';
      this.d.audio.knock(1, false);
      this.choices.push('Looked through the peephole');
      setTimeout(() => { if (this.peepOpen) this.sub('“…I can see your little shadow under the door, Alex.”', 5); }, 2500);
    } else if (this.chapter >= 5) {
      html = '<div style="font-size:60px">🌧️</div><div>Empty porch. Swinging bulb.<br/>…why is that comforting? He’s not out there.<br/>He’s in here with you.</div>';
    } else if (this.chapter === 3 && !this.strangerOut && !this.isDone('door')) {
      html = '<div style="font-size:60px">🌧️</div><div>Empty porch. Wet footprints lead AWAY…<br/>no. Toward the side of the house.<br/>Toward the BACK windows.</div>';
    } else {
      html = '<div style="font-size:60px">🌧️</div><div>Rain. The mailbox. The streetlamp buzzing.<br/>Everything normal. Everything fine.</div>';
    }
    this.ui.peephole(html);
    if (this.chapter === 3) this.done('peep');
  }
  closePeep() { this.peepOpen = false; this.d.player.frozen = false; this.ui.closePeephole(); }

  // ---------- endings ----------
  finish(id, custom) {
    if (this.finished) return;
    this.finished = true;
    this.scriptToken++;
    const A = this.d.audio;
    A.setHeart(false); A.setTV(false);
    const mins = Math.round((Date.now() - this.startTime) / 60000);
    const texts = {
      A: ['You slam into the neighbor’s porch screaming. Lights explode on up and down the street. Behind you, at the edge of the lawn, a tall figure STOPS — watches — and then simply… isn’t there anymore.\n\nThe police find wet footprints through YOUR house. All the way to the front door. Stopping where you stood.\n\nYou never sleep with the lights off again.',
        'The police find no one. But every officer who walks your hallway goes quiet at the parents’ window.'],
      B: ['Glass in your palms. Rain in your mouth. You hit the grass running and you do not look back — but you HEAR him, right behind the fence, matching you step for step, breathing like a man who has waited years for this.\n\nThen headlights. A car. A horn. And the breathing is gone.\n\nThe driver says you appeared out of nowhere, screaming. She says there was no one behind you.\n\nShe is wrong. You saw the streetlamp flicker as he stepped under it.',
        'You got out. That’s more than the footprints in the yard suggest anyone else did.'],
      C: ['Under the bed, cheek to the carpet, phone glowing against your chest. Footsteps circle the room. Once, the closet door creaks. Once, something kneels — you see black shoes by the bed skirt — and breathes.\n\n“…I can hear your little heart, Alex…”\n\nThen: SIRENS. Shouting. Running. A flashlight beam sweeps under the bed and finds your face.\n\n“Kid? KID, YOU’RE SAFE NOW.”\n\nThey never catch him. But they find his footprints. Under your window. In your hallway. Stopping, for a long time, beside your bed.',
        'You survived the night. The morning news calls it “a break-in.” You know better.'],
      D: [(custom ? custom + '\n\n' : '') + 'A hand like winter closes over your mouth.\n\nThe last thing you hear is breathing, right against your ear, almost tender:\n\n“…shhh…”\n\n[ECHES IN THE DARK — EPISODE 1: BAD END]',
        'He was always faster than you. Be smarter next time.'],
    };
    this.ui.ending(id, texts[id][0], texts[id][1],
      `⏱ ${mins} min · 👁 spotted ${this.spotted}× · 📄 notes ${this.notesFound.length}/8 · ${this.choices.length ? 'choices: ' + this.choices.slice(-4).join(' · ') : 'no choices made'}`);
  }

  // ================= INTERACTABLES =================
  register(I) {
    const halo = (x, y, z, r) => I.halo(x, y, z, r);
    const W = this.d.world;

    // ---- doors ----
    const doorDef = (id, x, z, label) => I.add({
      id: 'door-' + id, meshes: [halo(x, 1.2, z, 0.7)],
      prompt: () => {
        const d = W.doors.get(id);
        if (id === 'front' && this.chapter === 0 && !this.flags.deadbolt) return 'Lock the front door';
        if (id === 'front' && this.chapter === 3 && this.strangerOut && !this.isDone('door')) return 'Speak through the door';
        if (id === 'front' && this.chapter === 3 && this.strangerOut) return 'Front door (he is RIGHT THERE)';
        if (id === 'front' && this.chapter === 6 && this.flags.deadbolt && !this.flags.deadboltOff) return 'Throw the deadbolt & RUN';
        if (id === 'parents' && d.locked && !this.items.parentsKey) return 'Parents’ door (locked)';
        if (id === 'parents' && d.locked && this.items.parentsKey) return 'Unlock with key';
        return (d.open ? 'Close ' : 'Open ') + label;
      },
      onUse: () => this.toggleDoor(id),
    });
    doorDef('front', 0, 5.5, 'front door');
    doorDef('bed', -5.5, -1.5, 'bedroom door');
    doorDef('parents', 1.5, -1.5, 'parents’ door');
    doorDef('bath', 5.2, -1.5, 'bathroom door');
    doorDef('util', 7.25, -1.5, 'utility door');

    I.add({
      id: 'peephole', meshes: [halo(0, 1.6, 5.3, 0.4)],
      prompt: (c) => (c.player.pos.z < 5.4 ? 'Look through peephole' : null),
      onUse: () => this.peep(),
    });

    // ---- ch1 chores ----
    I.add({
      id: 'groceries', meshes: [halo(3.7, 1.25, 3.2, 0.6)],
      prompt: () => (this.chapter === 1 && !this.isDone('groceries') ? 'Put groceries away' : null),
      hold: () => 2, onUse: () => { this.done('groceries'); this.sub('Milk, eggs, pasta. Mom’s list, complete. The fridge hums approval.', 4); },
    });
    I.add({
      id: 'trashbag', meshes: [halo(4.9, 0.5, 2.6, 0.6)],
      prompt: () => (this.chapter === 1 && !this.isDone('trash') && !this.items.trash ? 'Grab the trash bag' : null),
      onUse: () => { this.items.trash = true; this.d.audio.pickup(); this.toast('🗑️ Trash bag acquired. It’s leaking. Great.'); },
    });
    I.add({
      id: 'trashbin', meshes: [halo(-2.6, 0.8, 6.3, 0.8)],
      prompt: () => (this.items.trash && !this.isDone('trash') ? 'Dump the trash' : null),
      onUse: () => { this.items.trash = false; this.d.audio.doorShut(); this.done('trash'); this.sub('The bin lid CLANGS. Across the street, the streetlamp flickers. Was someone standing under it?', 5); },
    });
    I.add({
      id: 'thermo', meshes: [halo(-1, 1.5, -1.3, 0.4)],
      prompt: () => (this.chapter === 1 && !this.isDone('thermo') ? 'Turn thermostat down (78°?!)' : 'Thermostat (72° — perfect)'),
      onUse: () => {
        if (this.chapter !== 1 || this.isDone('thermo')) return;
        this.d.audio.uiClick(); this.done('thermo');
        this.sub('72°. The vents sigh. Somewhere, the house ticks like a cooling engine.', 4);
      },
    });
    I.add({
      id: 'homework', meshes: [halo(-3.0, 0.95, -5.0, 0.6)],
      prompt: () => {
        if (this.chapter !== 1 || this.isDone('homework')) return null;
        return `Do homework (page ${this.homeworkPages + 1}/3)`;
      },
      hold: () => 8,
      onUse: () => {
        this.homeworkPages++; this.clockMin += 25;
        this.d.audio.blip(300, 0.3, 'triangle', 0.08, 100);
        if (this.homeworkPages >= 3) { this.done('homework'); this.sub('Done. Three pages of algebra. Your hand is dead but your conscience is clean.', 5); }
        else this.toast(`📝 Page ${this.homeworkPages}/3 done. Only ${3 - this.homeworkPages} more…`);
      },
    });

    // ---- ch2 dinner ----
    I.add({
      id: 'fridge', meshes: [halo(7.0, 1.2, 1.0, 0.7)],
      prompt: () => {
        if (this.chapter === 2 && !this.items.food && this.micro.state === 'idle') return 'Take the leftover pasta';
        if (this.items.food === 'hot' || this.micro.state === 'done') return null;
        return 'Fridge (leftover pasta, milk, regret)';
      },
      onUse: () => {
        if (this.chapter !== 2 || this.items.food || this.micro.state !== 'idle') { this.d.audio.uiClick(); return; }
        this.items.food = 'cold'; this.d.audio.pickup(); this.toast('🍝 Cold pasta. The microwave is right there.'); },
    });
    I.add({
      id: 'micro', meshes: [halo(7.2, 1.25, 1.9, 0.6)],
      prompt: () => {
        if (this.items.food === 'cold' && this.micro.state === 'idle') return 'Microwave the pasta (75s)';
        if (this.micro.state === 'running') return `Microwaving… (${Math.ceil(this.micro.t)}s)`;
        if (this.micro.state === 'done') return 'Take the hot pasta';
        return 'Microwave (empty, humming faintly)';
      },
      onUse: () => {
        if (this.items.food === 'cold' && this.micro.state === 'idle') {
          this.items.food = null; this.micro.state = 'running'; this.micro.t = CFG.times.microwave;
          W.microLight.intensity = 2; this.d.audio.uiClick();
          this.toast('⏱ 75 seconds. Maybe watch TV while you wait…');
        } else if (this.micro.state === 'done') {
          this.micro.state = 'idle'; this.items.food = 'hot'; this.d.audio.pickup();
          this.toast('🍝 Hot pasta! Eat it on the couch like a civilized goblin.');
        }
      },
    });
    I.add({
      id: 'tv', meshes: [halo(-2, 0.95, 1.0, 0.8)],
      prompt: () => (W.tvOn ? 'Turn TV off' : 'Turn TV on'),
      onUse: () => {
        if (!W.power) { this.d.audio.locked(); this.toast('📺 No power. Right.'); return; }
        W.setTV(!W.tvOn); this.d.audio.setTV(W.tvOn); this.d.audio.uiClick();
        if (W.tvOn) this.sub('“…LOCAL NEWS AT NINE. Our top story tonight: Hollow Creek police—” Sit down to watch.', 5);
      },
    });
    I.add({
      id: 'couch', meshes: [halo(-2, 0.8, 3.3, 0.9)],
      prompt: (c) => {
        if (c.player.sitting && this.items.food === 'hot') return 'Eat dinner (hold)';
        if (c.player.sitting) return 'Stand up';
        return 'Sit on the couch';
      },
      hold: (c) => (c.player.sitting && this.items.food === 'hot' ? 3 : 0),
      onUse: (c) => {
        if (c.player.sitting && this.items.food === 'hot') {
          this.items.food = null; this.done('dinner');
          this.sub('Peak cuisine: couch pasta. Eaten with a plastic fork. Zero regrets.', 5);
        } else this.sitToggle();
      },
    });

    // ---- drawer: batteries (ch4) + parents key (ch5) ----
    I.add({
      id: 'drawer', meshes: [halo(4.2, 0.75, 2.8, 0.6)],
      prompt: () => {
        if (!this.flags.batteries) return 'Search the junk drawer';
        if (this.chapter >= 5 && !this.items.parentsKey) return 'Search the drawer again (key?)';
        return 'Junk drawer (dead pens, takeout menus)';
      },
      onUse: () => {
        this.d.audio.uiClick();
        if (!this.flags.batteries) {
          this.flags.batteries = true; this.items.batteries++;
          this.items.battery = 100;
          this.toast('🔋 Batteries! Flashlight recharged to 100%.');
          this.sub('A full pack of AAs. Mom labels everything: “FLASHLIGHT — DO NOT STEAL -MOM.”', 4);
        } else if (this.chapter >= 5 && !this.items.parentsKey) {
          this.items.parentsKey = true; this.d.audio.pickup(); this.done('key');
          this.sub('Taped under the drawer: a brass key. “PARENT’S ROOM — ALEX DO NOT.” …Sorry, Mom.', 5);
        } else this.sub('Dead pens. Soy sauce packets. A Size D battery. Nope.', 3);
      },
    });

    // ---- ch4: flashlight + fuse ----
    I.add({
      id: 'flashlight', meshes: [halo(7.8, 1.3, -3.6, 0.6)],
      prompt: () => (!this.items.flash ? 'Take the flashlight' : null),
      onUse: () => { this.items.flash = true; this.d.audio.pickup(); this.done('flash'); this.toast('🔦 Flashlight! Press F to toggle. Watch the battery.'); },
    });
    I.add({
      id: 'fuse', meshes: [halo(7.8, 1.55, -2.6, 0.6)],
      prompt: () => {
        if (this.chapter !== 4 || this.isDone('fuse')) return 'Fuse box (humming normally)';
        return `Reset breaker ${this.fuseN + 1}/3 (hold)`;
      },
      hold: () => (this.chapter === 4 && !this.isDone('fuse') ? 2.5 : 0),
      onUse: () => {
        if (this.chapter !== 4 || this.isDone('fuse')) return;
        this.fuseN++; this.d.audio.staticBurst(); this.d.player.noise = 60;
        if (this.fuseN >= 3) {
          W.setPower(true); this.d.audio.powerUp(); this.done('fuse');
          this.sub('CLICK. The house gasps back to life. Light floods the hallway — and for one frame, a TALL SHADOW shrinks off the wall.', 6);
          this.flicker('hall', 1.5);
        } else this.toast(`⚡ Breaker ${this.fuseN}/3… the box growls.`);
      },
    });

    // ---- ch5: hiding + car keys ----
    I.add({
      id: 'hidebed', meshes: [halo(-6.4, 0.5, -3.3, 0.7)],
      prompt: (c) => (c.player.hidden === 'bed' ? 'Crawl out' : 'Hide under the bed'),
      onUse: () => this.hide('bed'),
    });
    I.add({
      id: 'hidecloset', meshes: [halo(-2.7, 1.2, -2.0, 0.7)],
      prompt: (c) => (c.player.hidden === 'closet' ? 'Step out' : 'Hide in the closet'),
      onUse: () => this.hide('closet'),
    });
    I.add({
      id: 'hidepcloset', meshes: [halo(3.2, 1.2, -2.0, 0.7)],
      prompt: (c) => (c.player.hidden === 'pcloset' ? 'Step out' : 'Hide in the parents’ closet'),
      onUse: () => this.hide('pcloset'),
    });
    I.add({
      id: 'carkeys', meshes: [halo(3.3, 1.0, -5.1, 0.6)],
      prompt: () => (this.chapter >= 5 && !this.items.carKeys ? 'Take the CAR KEYS' : null),
      onUse: () => {
        this.items.carKeys = true; this.d.audio.pickup(); this.done('carkeys');
        this.sub('Car keys. You can’t drive. But the panic button… the headlights… options. Or just RUN.', 6);
      },
    });

    // ---- ch6 escapes ----
    I.add({
      id: 'bedwindow', meshes: [halo(-5.5, 1.4, -5.35, 0.7)],
      prompt: () => {
        if (this.chapter < 6) return 'Bedroom window (Mom: NEVER open at night)';
        return 'CLIMB OUT the window (hold)';
      },
      hold: () => (this.chapter >= 6 ? 3 : 0),
      onUse: () => {
        if (this.chapter < 6) { this.sub('Mom’s rule #1: windows stay shut at night. …Rules might change tonight.', 4); return; }
        const P = this.d.player;
        W.escapeWinCol.on = false;
        P.hidden = null; P.frozen = false;
        P.pos.set(-5.5, CFG.eye, -6.5); P.setLook(-Math.PI / 2, 0); // face east, the running route
        P.noise = 100; this.d.audio.glassBreak();
        this.flags.escapedWindow = true;
        this.sub('Cold air. Wet grass. RUN — east side, around the fence, to the STREET.', 6);
        this.toast('🏃 REACH THE STREET (south, past the fence)!');
        const E = this.d.enemy;
        E.place(-1.5, -6.8, -Math.PI / 2); E.state = 'investigate'; E.target = { x: -5.5, z: -6.5 }; // out the back behind you
        E.speedMul = 1.15;
      },
    });
    I.add({
      id: 'neighbordoor', meshes: [halo(-18.2, 1.3, 7.3, 1.2)],
      prompt: () => (this.chapter === 6 ? 'BANG on the neighbor’s door (hold)' : null),
      hold: () => 1.5,
      onUse: () => {
        if (this.chapter !== 6) return;
        this.d.audio.knock(3, true);
        this.finish('A');
      },
    });

    // ---- notes ----
    const note = (id, x, y, z, cond) => I.add({
      id: 'note-' + id, meshes: [halo(x, y, z, 0.55)],
      prompt: () => ((!cond || cond()) && !this.noteOpen ? 'Read' : null),
      onUse: () => this.read(id),
    });
    note('mail', 2.2, 1.25, 9.0);
    note('fridge', 7.0, 1.55, 1.0);
    note('photo', -7.6, 0.95, 0.95);
    note('doodle', -2.7, 0.9, -5.1, () => this.chapter >= 1);
    note('parents', 0.6, 0.95, -4.2, () => this.flags.parentsOpen);
    note('bath', 5.2, 1.1, -2.0);
    note('manual', 7.8, 0.95, -3.0);
    note('masonNote', 0, 0.35, 5.15, () => this.flags.masonNote);

    // ---- light switches ----
    const sw = (room, x, z, label) => I.add({
      id: 'sw-' + room, meshes: [halo(x, 1.45, z, 0.32)],
      prompt: () => `${label} light (${W.power ? (W.roomLights[room]?.on ? 'on' : 'off') : 'no power'})`,
      onUse: () => {
        if (!W.power) { this.d.audio.locked(); return; }
        const r = W.roomLights[room];
        W.setRoomLight(room, !r.on); this.d.audio.uiClick();
      },
    });
    sw('living', -3.4, 0.32, 'Living room'); sw('kitchen', 3.4, 0.32, 'Kitchen');
    sw('hall', 0, -1.32, 'Hallway'); sw('bed', -5.0, -1.32, 'Bedroom');
    sw('parents', 2.0, -1.32, 'Parents’ room'); sw('bath', 5.9, -1.32, 'Bathroom');
    sw('util', 6.9, -1.32, 'Utility room');

    // ---- mirror ----
    I.add({
      id: 'mirror', meshes: [halo(5.2, 1.6, -1.9, 0.5)],
      prompt: () => 'Look in the mirror',
      onUse: () => {
        if (this.chapter >= 4 && !this.flags.mirrorLook) {
          this.flags.mirrorLook = true; this.d.audio.sting();
          this.sub('Your reflection blinks a half-second late. Behind it, for one frame: the hallway. A tall shape. Gone.', 6);
        } else this.sub('You look great. Terrified, but great.', 3);
      },
    });
  }
}

// three import needed for police light
import * as THREE from 'three';
or', meshes: [halo(5.2, 1.6, -1.9, 0.5)],
      prompt: () => 'Look in the mirror',
      onUse: () => {
        if (this.chapter >= 4 && !this.flags.mirrorLook) {
          this.flags.mirrorLook = true; this.d.audio.sting();
          this.sub('Your reflection blinks a half-second late. Behind it, for one frame: the hallway. A tall shape. Gone.', 6);
        } else this.sub('You look great. Terrified, but great.', 3);
      },
    });
  }
}

// three import needed for police light
import * as THREE from 'three';
