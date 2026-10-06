import type { Scenario } from '../../engine/types';
import { createFlatTireScene } from './scene';

// Shared vocabulary
const NUT = 'nut|bolt|lug';
const TIRE = 'tire|tyre|wheel';

export const flatTire: Scenario = {
  id: 'flat-tire',
  number: '01',
  title: 'Flat Tire',
  objective: 'Safely replace the tire.',
  intro: "Thump. Hiss. Wobble. Yeah. That's a flat. What do you do first?",
  outro: "Tire changed. Spare's on. Keep it under fifty on that donut, and get the flat fixed soon. Now. Let's see how you did.",

  possible: { knowledge: 22, safety: 14, sequence: 16, resourcefulness: 9 },

  steps: [
    {
      id: 'safe',
      rules: [
        ['hazard|flasher|blinker|emergency light|warning light|four way|4 way|indicators'],
        ['pull over|pull off|pull in|pull onto|pull to|move|drive|get|roll|park|steer|coast|go|head', 'safe|shoulder|side|off the road|verge|lot|out of traffic|curb|kerb|exit|away from traffic|level|flat ground|lay by|layby|lay-by|emergency lane'],
        ['pull over|pull off|shoulder|verge|hard shoulder'],
      ],
      ask: ['What do you do first?'],
      success: [
        "Good. Safety first. You're off the road and blinking like a lighthouse.",
        "Nice. Off the road, hazards on. Other drivers now know you exist.",
      ],
      delta: { safety: 3, knowledge: 1, sequence: 1 },
      bonuses: [
        { rules: [['hazard|flasher|blinker|emergency light|warning light|four way|4 way|indicators', 'pull|move|drive|safe|shoulder|side|off|verge|park|get']], delta: { knowledge: 1, safety: 1 }, note: 'Both at once. Efficient.' },
        { rules: [['level|flat ground|firm|solid|straight']], delta: { resourcefulness: 1 }, note: 'Level ground, too. Your jack thanks you.' },
      ],
      hint: 'Think about the traffic flying past you. And about the people in it.',
      reveal: "Get off the road and turn your hazards on. That one's non-negotiable.",
      choice: 'Pull onto the shoulder and switch on the hazards',
      distractors: [
        { label: 'Keep driving to the next town', action: 'driveOn' },
        { label: 'Stop right there in the lane to inspect it', action: 'laneStop' },
        { label: 'Call Dad', action: 'callDad' },
      ],
    },
    {
      id: 'secure',
      rules: [
        ['parking brake|handbrake|hand brake|e brake|ebrake|emergency brake|brake'],
        ['chock|wedge|block the|brick|rock|stone|log'],
        ['put|shift|leave|set|select|into|in', 'park$|gear|first$|reverse'],
        ['engine|ignition|car|it', 'off$'],
        ['secure|stabili|immobili', 'car|vehicle|it|wheel'],
      ],
      ask: ["You're parked on the shoulder. What next?", 'Okay, stopped. Now what?'],
      success: [
        "The car's not going anywhere. Exactly how you want it.",
        'Good. A car on a jack loves to roll. Yours now cannot.',
      ],
      delta: { safety: 2, knowledge: 2, sequence: 1 },
      bonuses: [
        { rules: [['chock|wedge|brick|rock|stone|block the']], delta: { resourcefulness: 1, safety: 1 }, note: 'Wheel chocks. Very pro.' },
        { rules: [['parking brake|handbrake|hand brake|e brake|ebrake|emergency brake', 'park$|gear']], delta: { knowledge: 1 }, note: '' },
      ],
      hint: 'Cars on jacks love to roll away. How do you stop that?',
      reveal: 'Parking brake on, in park or in gear, and chock the opposite wheel if you can.',
      tooEarly: [{ response: "Securing the car in the middle of traffic? Let's get off the road first.", delta: { safety: -2 } }],
      choice: 'Parking brake on and chock the wheels',
      distractors: [
        { label: 'Leave it in neutral for easy rolling', action: 'neutralGear' },
        { label: 'Kick the tire to assess the damage', action: 'kick' },
        { label: 'Jack it up straight away', action: '@lift' },
      ],
    },
    {
      id: 'triangle',
      rules: [['triangle|reflector|flare|cone|warning sign|warning device|warning marker']],
      ask: ['Car is secure. Anything before you start on the wheel?', "Car's locked in place. What else?"],
      success: [
        'Triangle out, well behind the car. Traffic now gets a polite heads up.',
        'Warning triangle placed. Drivers can see you from way back.',
      ],
      delta: { safety: 2, knowledge: 1, resourcefulness: 1 },
      bonuses: [
        { rules: [['meter|metre|feet|foot|steps|paces|yards|behind|back|far']], delta: { knowledge: 1 }, note: 'And far enough back. Nice.' },
      ],
      hint: 'Hazards are good. What else warns drivers from way back?',
      reveal: 'Put a warning triangle about fifty meters behind the car.',
      optional: {
        skipResponse: "Skipped the warning triangle. Bold on a busy road, but okay.",
        skipDelta: { safety: -1 },
      },
      tooEarly: [{ before: 'safe', response: "Walking a triangle down a live lane before you've even pulled over? Car first.", delta: { safety: -1 } }],
      choice: 'Set up a warning triangle well behind the car',
      distractors: [
        { label: 'Stand in the road waving your arms', action: 'waitStranger' },
        { label: 'Post about it online', action: 'post' },
        { label: 'Slide the jack under the car', action: '@jack' },
      ],
    },
    {
      id: 'loosen',
      rules: [
        ['loosen|crack|break|undo|unscrew|turn|slacken|start on|unbolt|untighten', NUT],
        ['loosen|crack|slacken', TIRE],
        ['wrench|tire iron|tyre iron|wheel brace|spanner|lug key|breaker bar', NUT],
      ],
      ask: ['Time to work on the wheel. Where do you start?', 'Okay. Hands on the wheel. First move?'],
      success: [
        "Smart. Loosen them while the tire's still on the ground, so the wheel can't spin.",
        "Exactly. Crack the nuts loose first. The ground holds the wheel still for you.",
      ],
      delta: { sequence: 3, knowledge: 2 },
      bonuses: [
        { rules: [['hubcap|hub cap|wheel cover|trim']], delta: { resourcefulness: 1 }, note: 'Hubcap off first. Detail person.' },
        { rules: [['counter|anti clockwise|anticlockwise|left|lefty']], delta: { knowledge: 1 }, note: 'Lefty loosey. Classic.' },
        { rules: [['before|on the ground|still down|first$|half turn|bit$|little|slightly|quarter']], delta: { knowledge: 1, sequence: 1 }, note: '' },
      ],
      hint: 'Before anything goes up, something needs to get a little less tight.',
      reveal: "Loosen the lug nuts while the wheel's still on the ground. Just a half turn.",
      tooEarly: [{ before: 'safe', response: "Wrenching on nuts in a live lane? Get off the road first.", delta: { safety: -2, sequence: -1 } }],
      choice: 'Loosen the lug nuts while the wheel is on the ground',
      distractors: [
        { label: 'Jack the car up first', action: '@lift' },
        { label: 'Take the nuts all the way off', action: 'removeNutsEarly' },
        { label: 'Whack the hubcap with a rock', action: 'kick' },
      ],
    },
    {
      id: 'jack',
      rules: [
        ['jack$|jacks$|jacking|lift point', 'position|place|put|set|under|slide|find|locate|point|get|grab|use|line'],
        ['jack point|jacking point|lift point|pinch weld|sill|frame'],
        ['jack$|jacking'],
      ],
      ask: ["Nuts are loose. Now what?", 'Wheel nuts cracked. Next?'],
      success: [
        "Jack's on the jacking point, right by the flat. Solid metal, not plastic.",
        'Good placement. Reinforced jacking point, close to the flat.',
      ],
      delta: { knowledge: 2, safety: 2, sequence: 1 },
      bonuses: [
        { rules: [['jack point|jacking point|lift point|pinch weld|frame|notch|sill|manual|marked|reinforced']], delta: { knowledge: 1, resourcefulness: 1 }, note: 'Proper jacking point. Textbook.' },
        { rules: [['near|next to|by the|closest|behind the|in front of the']], delta: { knowledge: 1 }, note: '' },
      ],
      missingNote: 'Pro tip: the jacking point is a reinforced spot on the frame. The manual shows it.',
      hint: "The jack can't just go anywhere. Where on the car is it meant to go?",
      reveal: 'Put the jack under the jacking point near the flat. A reinforced bit of frame. The manual shows it.',
      tooEarly: [
        { before: 'secure', response: "Jacking up an unsecured car. It's basically a skateboard now.", delta: { safety: -3, sequence: -1 } },
        { before: 'loosen', response: 'Congratulations, you have successfully made the next step harder.', delta: { sequence: -3 } },
      ],
      choice: 'Place the jack under the jacking point near the flat',
      distractors: [
        { label: 'Put the jack under the plastic bumper', action: 'badJackSpot' },
        { label: 'Stack bricks under the car', action: 'bricks' },
        { label: 'Lift the car by hand', action: 'forklift' },
      ],
    },
    {
      id: 'lift',
      rules: [
        ['jack|lift|raise|crank|pump|elevate|hoist|wind', 'up$|off the ground'],
        ['lift|raise|elevate|hoist', 'car|vehicle|it$|wheel|tire|tyre'],
        ['crank|pump|wind|turn', 'jack|handle'],
      ],
      ask: ['Jack is in position. And?', "Jack's set. What now?"],
      success: [
        'Up she goes. Just high enough for the flat to clear the ground.',
        'Car rising. Smooth. Flat is now hovering.',
      ],
      delta: { knowledge: 1, safety: 1, sequence: 2 },
      bonuses: [
        { rules: [['until|off the ground|inch|few cm|centimet|clear|just enough|enough']], delta: { knowledge: 1 }, note: 'Just enough height. Good restraint.' },
      ],
      hint: "Jack's in place. What's it actually for?",
      reveal: 'Crank the jack until the flat is just off the ground.',
      tooEarly: [
        { before: 'secure', response: "Jacking up an unsecured car. It's basically a skateboard now.", delta: { safety: -3, sequence: -1 } },
        { before: 'loosen', response: 'Congratulations, you have successfully made the next step harder.', delta: { sequence: -3 } },
        { before: 'jack', response: 'Lift it with what? The jack has to go somewhere first.', delta: { sequence: -1 } },
      ],
      choice: 'Raise the car until the flat clears the ground',
      distractors: [
        { label: 'Raise it as high as it will go', action: 'tooHigh' },
        { label: 'Crawl under to have a look', action: 'underCar' },
        { label: 'Wait for a kind stranger', action: 'waitStranger' },
      ],
    },
    {
      id: 'remove',
      rules: [
        ['remove|take|pull|unscrew|slide|undo|unbolt', 'tire|tyre|wheel|flat|nut|bolt|lug'],
        ['take it off|take off the|pull it off|get it off|slide it off'],
      ],
      ask: ['The flat is still... attached. Next?', 'Next move?'],
      success: [
        'Nuts off, flat off. Keep those nuts safe. They roll. Always toward drains.',
        'Flat removed. One less problem on the car.',
      ],
      delta: { knowledge: 1, sequence: 2, resourcefulness: 1 },
      bonuses: [
        { rules: [['pocket|safe place|hubcap|keep|lose|together|bag|container|cup']], delta: { resourcefulness: 2 }, note: 'Nuts somewhere safe. Rare wisdom.' },
      ],
      hint: "The car's up. The flat is still... attached.",
      reveal: 'Unscrew the lug nuts all the way and pull the flat off.',
      tooEarly: [
        { before: 'lift', response: "The tire's not coming off while the car is sitting on it. Physics: undefeated.", delta: { knowledge: -2, sequence: -1 } },
      ],
      choice: 'Unscrew the nuts and pull the flat off',
      distractors: [
        { label: 'Patch the hole with chewing gum', action: 'inflate' },
        { label: 'Lower the car first', action: '@lower' },
        { label: 'Bash it off with the jack handle', action: 'kick' },
      ],
    },
    {
      id: 'spare',
      rules: [
        ['spare|donut|doughnut|new tire|new tyre|new wheel|replacement|other tire|other tyre|other wheel'],
        ['put|mount|install|fit|slide|place|line up|align|hang|lift|attach', 'tire|tyre|wheel|on the stud|onto the stud'],
      ],
      ask: ["There's an empty space where a wheel should be. What now?", 'The flat is off. And then?'],
      success: [
        "Spare's on the studs. A small, sad donut, but it's yours.",
        'Spare mounted. It looks tiny. It will do the job.',
      ],
      delta: { knowledge: 1, sequence: 2, resourcefulness: 1 },
      bonuses: [
        { rules: [['line up|align|stud|bolt hole|holes|valve|facing out']], delta: { knowledge: 1 }, note: 'Lined up with the studs. Nice.' },
      ],
      hint: "There's an empty space where a wheel should be. Anything in the trunk?",
      reveal: 'Mount the spare onto the wheel studs.',
      tooEarly: [
        { before: 'remove', response: "There's already a wheel there. The flat one. Remember?", delta: { sequence: -1.5 } },
      ],
      choice: 'Mount the spare onto the wheel studs',
      distractors: [
        { label: 'Put the flat back on', action: 'flatBack' },
        { label: 'Drive on three wheels', action: 'driveOn' },
        { label: 'Lower the car now', action: '@lower' },
      ],
    },
    {
      id: 'tighten',
      rules: [
        ['tighten|screw|put|thread|fasten|hand tight|snug|secure|bolt|replace|reattach|back on', 'nut|bolt|lug'],
        ['tighten|fasten|bolt on|bolt it', 'wheel|tire|tyre|spare|it$'],
        ['hand tight|finger tight|snug'],
        ['screw|thread|tighten', 'them|back on|it$'],
      ],
      ask: ["And what's keeping it attached?", 'It is sitting there, loose. Next?'],
      success: [
        "Nuts on, snug, in a star pattern. Don't go full strength yet.",
        'Nuts threaded on and snugged up. The wheel stays put.',
      ],
      delta: { knowledge: 2, sequence: 2 },
      bonuses: [
        { rules: [['star|criss|cross|diagonal|opposite|alternat|zig']], delta: { knowledge: 2, resourcefulness: 1 }, note: 'Star pattern. Show-off.' },
        { rules: [['hand$|hand tight|by hand|finger|snug|loosely|lightly|a bit']], delta: { knowledge: 1 }, note: '' },
      ],
      missingNote: 'Pro tip: tighten in a star pattern so the wheel sits evenly.',
      hint: 'The spare is just sitting there. Loose. What holds a wheel on?',
      reveal: 'Thread the lug nuts back on and snug them up in a star pattern.',
      tooEarly: [
        { before: 'spare', response: "Tighten what, exactly? There's nothing new to tighten yet.", delta: { sequence: -1.5 } },
      ],
      choice: 'Thread the nuts on and snug them in a star pattern',
      distractors: [
        { label: 'Crank each one as hard as you can', action: 'fullForce' },
        { label: "Skip the nuts, it'll hold", action: 'skipNuts' },
        { label: 'Lower the car first', action: '@lower' },
      ],
    },
    {
      id: 'lower',
      rules: [
        ['lower|drop|let down|let it down|bring down|bring it down|release|down$', 'car|jack|it$|vehicle|down$'],
        ['lower|let down|let it down'],
      ],
      ask: ["Car's still floating. Last move?", 'Nearly there. Final step?'],
      success: [
        "Car's down. Final tighten in a star pattern, and you're done.",
        'Wheels on the ground. Nuts fully tightened. Done.',
      ],
      delta: { safety: 1, sequence: 2, knowledge: 1 },
      bonuses: [
        { rules: [['tighten|torque|fully|all the way|final|again|properly|firm|hard']], delta: { knowledge: 2, sequence: 1, safety: 1 }, note: 'And a final tighten once it\'s down. Perfect.' },
        { rules: [['pressure|check|recheck|re check|later|after a few|garage|fix the flat']], delta: { resourcefulness: 1 }, note: '' },
      ],
      missingNote: 'Remember to fully tighten the nuts once it\'s down. I did it for you this time.',
      hint: 'Wheels work better on the ground. Then one last thing.',
      reveal: 'Lower the car, then fully tighten the nuts in a star pattern.',
      tooEarly: [
        { before: 'lift', response: "It's... already down. That's kind of the problem.", delta: { knowledge: -1 } },
        { before: 'spare', response: 'Lowering a car with no wheel. It lands on the brake disc. Expensively.', delta: { safety: -2, sequence: -2 } },
        { before: 'tighten', response: 'Lowering onto a loose wheel. It wobbles off like a sad frisbee.', delta: { safety: -3, sequence: -1 } },
      ],
      choice: 'Lower the car, then tighten the nuts fully',
      distractors: [
        { label: 'Drive off with it still on the jack', action: 'jackDrive' },
        { label: 'Leave the nuts finger tight forever', action: 'skipTighten' },
        { label: 'Call Dad to check your work', action: 'callDad' },
      ],
    },
  ],

  wrongActions: [
    // --- priority: dangerous or very specific ---
    {
      id: 'underCar', priority: true, scene: 'wobble',
      rules: [['crawl under|crawl beneath|lie under|lay under|lie down under|climb under|get under|go under|reach under|look under|slide under|work under|get underneath|go underneath|crawl underneath']],
      response: ["Never put any part of you under a car on a jack. They slip. You don't respawn."],
      delta: { safety: -5 },
    },
    {
      id: 'removeNutsEarly', priority: true, from: 'loosen', until: 'loosen',
      rules: [
        ['remove|take off|take out|all the way|completely|fully|entirely', NUT],
        [NUT, 'off$|out$'],
      ],
      response: ['Loosen, not remove. Unless you want the wheel to fall off mid-lift.'],
      delta: { sequence: -2, safety: -1 },
    },
    {
      id: 'badJackSpot', priority: true, from: 'secure', until: 'lift', scene: 'wobble',
      rules: [['jack|lift', 'bumper|plastic|door|engine|oil pan|exhaust|middle of the car|anywhere|wherever|on the tire|on the wheel|on the tyre']],
      response: ["That's the plastic bumper. It's now a former bumper."],
      delta: { knowledge: -3 },
    },
    {
      id: 'tooHigh', priority: true, from: 'lift', until: 'lift', scene: 'wobble',
      rules: [['as high as|high as|all the way up|max|highest|really high|super high']],
      response: ['Maximum height achieved. Stability not included.'],
      delta: { safety: -2 },
    },
    {
      id: 'flatBack', priority: true, from: 'spare', until: 'spare',
      rules: [['flat|old tire|old tyre|old wheel|same tire|same wheel|original', 'back|reinstall|put|mount']],
      response: ["You've successfully reinstalled the problem."],
      delta: { knowledge: -3 },
    },
    {
      id: 'fullForce', priority: true, from: 'tighten', until: 'tighten', scene: 'wobble',
      rules: [['all my might|as hard as|full force|full strength|max torque|super tight|really tight|as tight as|crank']],
      response: ["Full strength while it's on the jack? The whole car wobbles. Snug now, final tighten once it's down."],
      delta: { safety: -2 },
    },
    {
      id: 'skipNuts', priority: true, from: 'spare', until: 'tighten', ignoreNegation: true,
      rules: [['skip|without|no need|forget|don\'t need|dont need|leave out|leave off', NUT]],
      response: ['The wheel will leave without you. At speed.'],
      delta: { safety: -4 },
    },
    {
      id: 'skipTighten', priority: true, from: 'lower', until: 'lower', ignoreNegation: true,
      rules: [['leave|forget|skip|no need|good enough|forever', 'tight|nut|loose']],
      response: ['Finger tight forever. The wheel has started making plans to leave.'],
      delta: { safety: -3 },
    },
    {
      id: 'laneStop', until: 'safe',
      rules: [['stay|stop|park|change|fix|stand|inspect|check|get out|look', 'lane$|middle of the road|in the road|where i am|right here|right there|on the highway|in traffic']],
      response: ['Changing a tire in a live lane. Traffic would like a word. Several, actually.'],
      delta: { safety: -4 },
    },
    // --- ordinary mistakes ---
    {
      id: 'driveOn', scene: 'wobble', until: 'tighten',
      rules: [
        ['drive|keep going|keep driving|limp|carry on|floor it|continue|push on|speed', 'on it|on the flat|home|anyway|rim|next town|to work|garage|shop|station|keep|three wheel|3 wheel|fine'],
        ['keep driving|keep going|carry on|floor it|ignore it|ignore the|just drive|drive on'],
      ],
      response: ['Bold strategy. Your tire strongly disagrees.'],
      delta: { safety: -4 },
    },
    {
      id: 'jackDrive', from: 'lower', until: 'lower', scene: 'wobble',
      rules: [['drive|go$|leave|take off|head', 'jack|away|off$|home|now']],
      response: ["The jack has been dragged forty meters. It's retired now."],
      delta: { safety: -3 },
    },
    {
      id: 'neutralGear',
      rules: [['neutral']],
      response: ['Neutral. A gear known for its strong commitment to rolling away.'],
      delta: { safety: -3 },
    },
    {
      id: 'callDad',
      rules: [['call|phone|text|ring|facetime|ask|get', 'dad$|daddy|father|mom$|mum$|mother|parent|pops|papa|brother|uncle|boyfriend|girlfriend|husband|wife|friend']],
      response: ["Dad picks up, sighs deeply, and asks if you've checked the trunk. Let's try this ourselves."],
      delta: { resourcefulness: -2 },
    },
    {
      id: 'callTow',
      rules: [['call|phone|ring|wait for|get', 'tow|aaa|roadside|mechanic|insurance|rac$|aa$|garage|help|911|police|breakdown']],
      response: ["Totally valid in real life. But they're ninety minutes out and your phone's on four percent. Let's fix it."],
      delta: { resourcefulness: -1 },
    },
    {
      id: 'kick',
      rules: [['kick|punch|hit|smack|bash|slap|stomp|whack|beat']],
      response: ['The tire remains flat. Your foot now also hurts.'],
      delta: { knowledge: -2 },
    },
    {
      id: 'panic',
      rules: [['panic|cry|scream|freak|yell|swear|curse|shit|oh no|crap|sob|give up|lose it']],
      response: ['Valid emotion. Not a valid repair strategy.'],
      delta: { knowledge: -1 },
    },
    {
      id: 'inflate',
      rules: [['pump it|inflate|air$|blow it|blow up|fix a flat|sealant|patch|tape|glue|gum$|chewing gum|duct']],
      response: ["There's a nail-sized hole in it. Air's leaving faster than it's arriving."],
      delta: { knowledge: -2 },
    },
    {
      id: 'abandon',
      rules: [['walk|uber|lyft|taxi|cab$|leave the car|abandon|hitchhike|bus$|sell the car|buy a new|new car|run away']],
      response: ['Walking away from your problems. Classic. The car will remember this.'],
      delta: { resourcefulness: -2 },
    },
    {
      id: 'forklift', scene: 'wobble',
      rules: [['lift|pick up|hold|raise|deadlift', 'by hand|with my hand|bare hand|my back|myself|my arms|with my strength']],
      response: ['You are not a forklift. Your spine has filed a complaint.'],
      delta: { safety: -2 },
    },
    {
      id: 'bricks', from: 'jack',
      rules: [['brick|rock|stone|log|book|cinder', 'under|stack|prop']],
      response: ['Improvised stacking. Creative. Structurally terrifying.'],
      delta: { safety: -3 },
    },
    {
      id: 'waitStranger',
      rules: [['wait|hope|pray|flag|wave|stranger|passer|hitch|someone|somebody|thumb']],
      response: ['You wave. Fourteen cars pass. One honks supportively.'],
      delta: { resourcefulness: -1, safety: -1 },
    },
    {
      id: 'post',
      rules: [['post|tweet|instagram|tiktok|story|selfie|photo|picture|film|vlog']],
      response: ['Great content. Zero progress. The tire remains flat, now on camera.'],
      delta: { resourcefulness: -1 },
    },
    {
      id: 'askAi',
      rules: [['google|youtube|chatgpt|ai$|tutorial|video|search|look it up|claude']],
      response: ["Tutorial loading. Unskippable ad. Two percent signal. Let's do this live."],
      delta: {},
    },
  ],

  neutralActions: [
    {
      id: 'getTools',
      rules: [['get|grab|take out|find|locate|open|check|unload', 'trunk|boot|tool|kit|equipment|spare|jack$|wrench|tire iron']],
      response: ['Good call. Spare, jack and wrench, out of the trunk.'],
      delta: { resourcefulness: 1 },
    },
    {
      id: 'manual',
      rules: [['manual|handbook|instructions|guide']],
      response: ['Reading the manual. A rare and powerful move.'],
      delta: { resourcefulness: 1, knowledge: 0.5 },
    },
    {
      id: 'light',
      rules: [['flashlight|torch|phone light|headlamp|head torch|light up']],
      response: ["Light on. Good thinking, it's getting dark."],
      delta: { resourcefulness: 1 },
    },
    {
      id: 'vest',
      rules: [['vest|hi vis|high vis|hivis|reflective|gloves|jacket']],
      response: ['Hi-vis on. Fashion: questionable. Safety: excellent.'],
      delta: { safety: 1 },
    },
    {
      id: 'passengers',
      rules: [['get out|step out|exit|passengers|everyone out|kids', 'passenger|away from traffic|safe side|other side|barrier|out$']],
      response: ['Everyone out, on the side away from traffic. Nice.'],
      delta: { safety: 1 },
    },
  ],

  diagnoses: [
    { min: 90, title: 'The Unpaid Mechanic', line: 'You are now the one people call.' },
    { min: 75, title: 'The Reliable One', line: "You probably won't call your dad this time." },
    { min: 60, title: 'The Confident Improviser', line: "You'll get there. Eventually. Probably." },
    { min: 40, title: 'The YouTube Apprentice', line: "You're one tutorial away from danger." },
    { min: 0, title: 'The Roadside Liability', line: 'Please just call your dad.' },
  ],

  highlights: [
    ['hazard|flasher|blinker|indicator|warning light', 'hazards'],
    ['brake|chock|wedge|park', 'chock'],
    ['triangle|reflector|cone|flare', 'triangle'],
    ['wrench|iron|brace|spanner|nut|lug|bolt', 'nuts'],
    ['jack', 'jack'],
    ['spare|donut|doughnut', 'spare'],
    ['tire|tyre|wheel|flat', 'wheel'],
  ],

  createScene: createFlatTireScene,
};
