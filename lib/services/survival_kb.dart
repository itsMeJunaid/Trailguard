import '../models/user_profile.dart';

/// One answerable survival topic.
class _Topic {
  final List<String> keywords;
  final String title;
  final String body;

  /// Higher wins when a question matches more than one topic. Life-threatening
  /// topics outrank general ones so "bleeding while lost" answers the bleeding.
  final int priority;

  const _Topic({
    required this.keywords,
    required this.title,
    required this.body,
    this.priority = 0,
  });
}

/// TrailGuard's built-in survival guide.
///
/// This is what answers when the Gemma model is not loaded — the whole web
/// build, and on-device before the download finishes. It is deliberately not a
/// "model unavailable" apology: someone asking how to purify water in the
/// backcountry needs the answer, not an error message.
///
/// Scope is honest: common, high-frequency backcountry situations with
/// well-established first-aid and fieldcraft answers. Anything outside that
/// returns null and the caller falls back to [notFound].
class SurvivalKnowledgeBase {
  static const _topics = <_Topic>[
    // ── Medical, highest priority ────────────────────────────────────
    _Topic(
      priority: 10,
      keywords: ['snake', 'snakebite', 'bitten by a snake', 'viper', 'adder'],
      title: 'Snake bite',
      body: '1. Move away from the snake — most bites happen twice.\n'
          '2. Keep the limb BELOW heart level and as still as possible.\n'
          '3. Remove rings, watches and anything tight before swelling starts.\n'
          '4. Mark the swelling edge with a pen and note the time.\n'
          '5. Walk out slowly if you must; do not run.\n\n'
          'Do NOT cut, suck, apply ice, or use a tourniquet — all of them make '
          'the outcome worse. Antivenom is the treatment; getting to it is the '
          'goal.',
    ),
    _Topic(
      priority: 10,
      keywords: ['bleed', 'bleeding', 'blood', 'cut', 'wound', 'laceration', 'gash'],
      title: 'Severe bleeding',
      body: '1. Direct pressure, hard, with the cleanest cloth you have — a '
          'full 10 minutes without lifting to peek.\n'
          '2. Elevate above the heart if no fracture is suspected.\n'
          '3. Bleeding through? Add layers on top. Never remove the first one.\n'
          '4. Still bleeding from a limb after 10 minutes: tourniquet 5–7 cm '
          'above the wound, tighten until it stops, write down the time.\n\n'
          'Do not remove an impaled object — pad around it and leave it in.',
    ),
    _Topic(
      priority: 9,
      keywords: ['hypothermia', 'freezing', 'so cold', 'shivering', 'cold and wet', 'frostbite'],
      title: 'Cold exposure',
      body: 'Shivering that stops without warming up is a red flag — that is '
          'moderate hypothermia.\n'
          '1. Get out of the wind and off the ground. Ground steals more heat '
          'than air.\n'
          '2. Replace wet layers with dry ones. Wet clothing is the usual cause.\n'
          '3. Insulate the head, neck and torso first, not the hands and feet.\n'
          '4. Warm sweet drinks if fully alert. Nothing by mouth if drowsy.\n'
          '5. Skin-to-skin contact inside a bag beats a fire you cannot light.\n\n'
          'Handle a severely cold person gently — rough movement can trigger '
          'cardiac arrest.',
    ),
    _Topic(
      priority: 9,
      keywords: ['heat stroke', 'heatstroke', 'heat exhaustion', 'overheating', 'too hot', 'dehydrated', 'dehydration'],
      title: 'Heat illness',
      body: 'Sweating heavily but still sweating is heat exhaustion. Hot skin, '
          'confusion and no sweat is heat stroke — a genuine emergency.\n'
          '1. Shade, immediately. Lie down, feet slightly raised.\n'
          '2. Loosen clothing; wet the skin and fan it. Evaporation cools '
          'faster than anything you can drink.\n'
          '3. Cool water in sips, with a pinch of salt or an electrolyte tab.\n'
          '4. Cold packs to the neck, armpits and groin.\n\n'
          'Confusion or unconsciousness means cool aggressively and get help — '
          'do not wait to see if it passes.',
    ),
    _Topic(
      priority: 8,
      keywords: ['fracture', 'broken', 'broke my', 'splint', 'bone'],
      title: 'Suspected fracture',
      body: '1. Do not straighten the limb. Splint it in the position you '
          'found it.\n'
          '2. Pad with clothing, then secure with something rigid — trekking '
          'pole, branch, rolled sleeping mat.\n'
          '3. Immobilise the joint above AND below the break.\n'
          '4. Check fingers or toes past the splint: warm, pink, and can they '
          'feel you? Recheck every 15 minutes. Loosen if they go cold or blue.\n\n'
          'An open fracture (bone through skin) — cover with a clean dressing, '
          'do not push it back in.',
    ),
    _Topic(
      priority: 8,
      keywords: ['burn', 'burnt', 'burned', 'scald'],
      title: 'Burns',
      body: '1. Cool running water for a full 20 minutes. This works up to '
          'three hours after the burn — it is never too late to start.\n'
          '2. Remove rings and watches before swelling.\n'
          '3. Cover loosely with a clean non-fluffy dressing or cling film.\n'
          '4. Do not pop blisters, and keep nothing greasy on it.\n\n'
          'Get help for: anything bigger than the casualty\'s palm, any burn to '
          'face, hands, feet or joints, or any burn that looks white or leathery.',
    ),
    _Topic(
      priority: 8,
      keywords: ['allergic', 'allergy', 'anaphyla', 'epipen', 'sting', 'wasp', 'bee'],
      title: 'Allergic reaction',
      body: '1. Adrenaline auto-injector into the outer thigh if you have one — '
          'through clothing is fine. Do not hesitate over it.\n'
          '2. Sit upright if breathing is hard; lie flat with legs raised if '
          'faint. Never stand them up.\n'
          '3. A second dose after 5 minutes if no improvement.\n'
          '4. Bee sting: scrape the sting out sideways, do not pinch it.\n\n'
          'Swelling of lips, tongue or throat, or any change in voice, is '
          'anaphylaxis until proven otherwise.',
    ),
    _Topic(
      priority: 7,
      keywords: ['sprain', 'twisted', 'ankle', 'knee', 'rolled'],
      title: 'Sprains',
      body: 'Remember RICE, and do it before the swelling sets in.\n'
          '1. Rest — stop, do not "walk it off" on rough ground.\n'
          '2. Ice or cold water, 15 minutes.\n'
          '3. Compression with a bandage, firm but not numbing.\n'
          '4. Elevate above the heart.\n\n'
          'If they cannot put any weight on it for four steps, treat it as a '
          'possible fracture and splint it.',
    ),
    _Topic(
      priority: 6,
      keywords: ['blister', 'hot spot', 'rubbing', 'heel'],
      title: 'Blisters',
      body: 'Stop at the "hot spot" stage — that is the cheapest fix you will '
          'get all day.\n'
          '1. Dry the skin, then tape it or apply a blister plaster.\n'
          '2. Already blistered and small: leave it intact and pad around it '
          'with a doughnut of foam.\n'
          '3. Large and tense: drain from the edge with a sterilised needle, '
          'leave the roof on, cover.\n\n'
          'Redness spreading out from it, or pus, means infection — that needs '
          'attention, not more tape.',
    ),

    // ── Core fieldcraft ──────────────────────────────────────────────
    _Topic(
      priority: 5,
      keywords: ['lost', 'no idea where', 'don\'t know where i am', 'disoriented', 'lost the trail'],
      title: 'Lost',
      body: 'Stop. The urge to push on is what turns lost into missing.\n\n'
          'S — Stop and sit down for 10 minutes.\n'
          'T — Think: when were you last certain of your position?\n'
          'O — Observe: map, compass, terrain features, the sun.\n'
          'P — Plan, then act on the plan.\n\n'
          'If you cannot retrace with confidence, stay put and make yourself '
          'findable. Searchers move faster than you do. Moving downhill toward '
          'water and following it downstream is the fallback when you must '
          'move — but staying put is usually the better call.',
    ),
    _Topic(
      priority: 5,
      keywords: ['water', 'drink', 'purify', 'purification', 'filter', 'thirsty', 'stream'],
      title: 'Water',
      body: 'Best sources: fast-moving water high up, above any habitation or '
          'grazing. Avoid still water and anything with algae.\n\n'
          'Making it safe, best first:\n'
          '1. Boil — a rolling boil for one minute (three above 2,000 m). This '
          'is the only method that handles everything.\n'
          '2. Filter (0.2 micron) — bacteria and protozoa, not viruses.\n'
          '3. Chemical tablets — 30 minutes, longer if the water is cold.\n'
          '4. Clear water in a PET bottle, on its side in full sun, 6 hours.\n\n'
          'Let silty water settle or strain it through cloth first. Being '
          'dehydrated is a bigger danger than most waterborne bugs — do not '
          'ration water you are carrying.',
    ),
    _Topic(
      priority: 5,
      keywords: ['shelter', 'sleep', 'camp', 'bivouac', 'tarp', 'overnight'],
      title: 'Shelter',
      body: 'Insulation beneath you matters more than the roof. The ground will '
          'take your heat all night.\n\n'
          '1. Site: out of the wind, off ridgelines and gullies, away from dead '
          'branches and above any high-water line.\n'
          '2. Floor: 15–20 cm of dry leaves, pine needles or spruce boughs.\n'
          '3. Roof: tarp or a lean-to angled into the wind. Keep the interior '
          'just big enough for your body — a large shelter is a cold one.\n'
          '4. Shingle debris from the bottom up so water runs off.\n\n'
          'Build it while you still have light. Everything takes twice as long '
          'as you think.',
    ),
    _Topic(
      priority: 5,
      keywords: ['fire', 'light a fire', 'tinder', 'kindling', 'matches'],
      title: 'Fire',
      body: '1. Clear a 2 m circle down to bare earth, ring it with stones.\n'
          '2. Gather far more than you think: a hat full of tinder, an armful '
          'of pencil-thin kindling, then wrist-thick fuel.\n'
          '3. Tinder that works wet: birch bark, resinous pine, dead standing '
          'twigs snapped from the tree — never off the ground.\n'
          '4. Build a small tepee over the tinder, light from the upwind side, '
          'and feed it gradually.\n\n'
          'Prepare every stage before striking a spark. Most failed fires are '
          'ones that ran out of kindling at the critical moment.',
    ),
    _Topic(
      priority: 5,
      keywords: ['navigate', 'navigation', 'compass', 'bearing', 'direction', 'north', 'map'],
      title: 'Navigation without GPS',
      body: 'Finding north:\n'
          '• Sun rises roughly east, sets roughly west. At local noon it sits '
          'due south in the northern hemisphere, due north in the southern.\n'
          '• Analogue watch, northern hemisphere: point the hour hand at the '
          'sun; south is halfway between the hand and 12.\n'
          '• Clear night, north: the two end stars of the Plough point to '
          'Polaris. South: the long axis of the Southern Cross.\n\n'
          'Then pick a distinctive landmark on your bearing, walk to it, and '
          'take a new one. Handrails — ridges, streams, fences — beat compass '
          'work when you can find them.',
    ),
    _Topic(
      priority: 6,
      keywords: ['rescue', 'signal', 'help', 'sos', 'whistle', 'attract attention', 'search'],
      title: 'Signalling for rescue',
      body: 'Three of anything means distress — three whistle blasts, three '
          'flashes, three fires in a triangle. Pause, then repeat.\n\n'
          '• Whistle carries far further than your voice and costs no energy.\n'
          '• A mirror or phone screen flash is visible for miles in sun.\n'
          '• Make yourself big: bright kit spread on open ground, a ground-to-'
          'air X, smoke by day and flame by night.\n'
          '• Choose open ground — a clearing, a ridge, a riverbank. Forest '
          'canopy hides you completely from the air.\n\n'
          'Stay put once you have started signalling.',
    ),
    _Topic(
      priority: 7,
      keywords: ['bear', 'cougar', 'mountain lion', 'wolf', 'boar', 'moose', 'animal', 'wildlife'],
      title: 'Large animal encounters',
      body: 'Universal rules: do not run, do not turn your back, give it an '
          'exit.\n\n'
          '• Bear: speak calmly, look large, back away slowly. Brown/grizzly '
          'charging — play dead, face down, hands over neck. Black bear — fight '
          'back, aim for the face.\n'
          '• Cougar: look as big as possible, maintain eye contact, shout, '
          'fight back if attacked. Never crouch or turn away.\n'
          '• Moose or boar: these you do run from, and put a solid tree between '
          'you. They charge but rarely pursue.\n\n'
          'Most encounters end because the animal was surprised. Make noise on '
          'blind corners.',
    ),
    _Topic(
      priority: 6,
      keywords: ['eat', 'edible', 'mushroom', 'berry', 'berries', 'plant', 'forage', 'food', 'poisonous'],
      title: 'Eating wild food',
      body: 'Do not, unless you are certain. You can go three weeks without '
          'food; a single misidentified mushroom can kill you in a day.\n\n'
          '• No mushrooms. The deadly ones look like the safe ones, and there '
          'is no field test that works.\n'
          '• Avoid: white or yellow berries, anything with milky sap, almond-'
          'smelling leaves, three-leaflet patterns, umbrella-shaped flower '
          'heads.\n'
          '• Generally safer if positively identified: rose hips, dandelion, '
          'plantain, cattail roots, pine needles for tea.\n\n'
          'Hunger is uncomfortable. It is not the thing that will hurt you.',
    ),
    _Topic(
      priority: 7,
      keywords: ['lightning', 'thunder', 'storm', 'thunderstorm'],
      title: 'Lightning',
      body: 'Count between flash and thunder — under 30 seconds means you are '
          'already in the risk zone.\n\n'
          '1. Get off summits, ridges and open ground immediately.\n'
          '2. Away from lone trees, water, and metal — poles, fences, frames.\n'
          '3. Best position: a low point, crouched on the balls of your feet, '
          'heels together, hands off the ground. Small contact patch.\n'
          '4. Spread the group at least 15 m apart.\n'
          '5. Wait 30 minutes after the last thunder before moving on.\n\n'
          'A struck person carries no charge — start CPR immediately if needed.',
    ),
    _Topic(
      priority: 6,
      keywords: ['river', 'crossing', 'ford', 'stream crossing', 'creek'],
      title: 'River crossing',
      body: 'The most common way experienced hikers die. Turning back is a '
          'legitimate answer.\n\n'
          '1. Scout up and down for the widest, shallowest, slowest stretch. '
          'Narrow means deep and fast.\n'
          '2. Undo your hip belt and sternum strap so the pack can be shed.\n'
          '3. Face upstream, shuffle sideways, three points of contact, using '
          'a pole on the upstream side.\n'
          '4. Groups: link arms and move as one unit.\n\n'
          'Above knee-deep with any real current, do not attempt it. Swept off '
          'your feet — go feet-first downstream on your back.',
    ),
    _Topic(
      priority: 6,
      keywords: ['tick', 'insect', 'mosquito', 'leech', 'bug bite'],
      title: 'Ticks and insects',
      body: 'Ticks: grip with tweezers as close to the skin as you can, pull '
          'straight out with steady pressure. No twisting, no burning, nothing '
          'greasy — all of those make it regurgitate.\n\n'
          'Clean the site, note the date. An expanding bullseye rash or a fever '
          'in the following weeks needs a doctor and the date you were bitten.\n\n'
          'Prevention beats all of it: trousers tucked into socks, repellent on '
          'clothing, and a full body check each evening — behind knees, '
          'waistband, hairline.',
    ),
    _Topic(
      priority: 6,
      keywords: ['altitude', 'ams', 'mountain sickness', 'elevation sick', 'headache high'],
      title: 'Altitude sickness',
      body: 'Headache plus any of: nausea, dizziness, exhaustion, poor sleep, '
          'above ~2,500 m.\n\n'
          '1. Stop ascending. Do not "push through" it.\n'
          '2. Rest, hydrate, no alcohol.\n'
          '3. Not better in 24 hours, or getting worse — descend. 500–1,000 m '
          'usually resolves it.\n\n'
          'Descend immediately, at night if necessary, for confusion, a '
          'stumbling walk, or breathlessness at rest. Those are HACE and HAPE '
          'and they kill. Climb high, sleep low.',
    ),
  ];

  /// Best-matching answer for [question], or null when nothing fits well.
  static String? answer(String question, {UserProfile? profile}) {
    final q = question.toLowerCase();

    _Topic? best;
    var bestScore = 0;
    for (final topic in _topics) {
      var score = 0;
      for (final k in topic.keywords) {
        if (q.contains(k)) score += k.length;
      }
      if (score == 0) continue;
      score += topic.priority * 4;
      if (score > bestScore) {
        bestScore = score;
        best = topic;
      }
    }
    if (best == null) return null;

    final name = (profile?.name ?? '').split(' ').first;
    final greeting = name.isEmpty ? '' : '$name — ';
    return '$greeting**${best.title}**\n\n${best.body}${_personalNote(best, profile)}';
  }

  /// Surfaces the profile facts that actually matter for this topic, rather
  /// than pasting the whole medical record onto every answer.
  static String _personalNote(_Topic topic, UserProfile? p) {
    if (p == null || p.isEmpty) return '';
    final notes = <String>[];
    final medical = {'Snake bite', 'Severe bleeding', 'Allergic reaction'};

    if (medical.contains(topic.title)) {
      if ((p.bloodGroup ?? '').isNotEmpty) notes.add('blood group ${p.bloodGroup}');
      if ((p.allergies ?? '').isNotEmpty) notes.add('allergies: ${p.allergies}');
      if ((p.medications ?? '').isNotEmpty) {
        notes.add('medication: ${p.medications}');
      }
    }
    if (notes.isEmpty) return '';
    return '\n\n_On your profile — ${notes.join(' · ')}. '
        'Tell any responder this._';
  }

  /// Shown when nothing matched, so the reply is still a way forward.
  static String notFound({UserProfile? profile}) {
    final name = (profile?.name ?? '').split(' ').first;
    final greeting = name.isEmpty ? '' : '$name, ';
    return '${greeting}I don\'t have a built-in answer for that one.\n\n'
        'The offline guide covers: **water**, **fire**, **shelter**, '
        '**navigation**, **getting lost**, **signalling for rescue**, '
        '**river crossings**, **lightning**, **wildlife**, **wild food**, '
        'and first aid for **bleeding**, **fractures**, **burns**, '
        '**snake bite**, **allergic reactions**, **sprains**, **blisters**, '
        '**cold** and **heat**.\n\n'
        'Ask about any of those, or load a Gemma model for open-ended answers.';
  }

  /// Suggestions for the empty chat. Short [label] so a row of chips packs
  /// two or three across; the full [question] is what actually gets sent, so
  /// the transcript still reads like a conversation.
  static const starters = <({String label, String question})>[
    (label: 'Purify water', question: 'How do I purify water from a stream?'),
    (label: "I'm lost", question: "I think I'm lost — what should I do now?"),
    (label: 'Build shelter', question: 'How do I build a shelter for the night?'),
    (label: 'Stop bleeding', question: 'Someone is bleeding badly — what do I do?'),
    (label: 'Lightning', question: "There's a thunderstorm coming — how do I stay safe?"),
    (label: 'Signal rescue', question: 'How do I signal for rescue?'),
    (label: 'Snake bite', question: 'Someone has been bitten by a snake'),
    (label: 'Start a fire', question: 'How do I start a fire with damp wood?'),
  ];
}
