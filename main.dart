import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() => runApp(const GfApp());

class GfApp extends StatelessWidget {
  const GfApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AI Girlfriend',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: Colors.pink, brightness: Brightness.dark, useMaterial3: true),
        themeMode: ThemeMode.system,
        home: const ChatPage(),
      );
}

class Msg {
  final String role; // user | model
  final String text;
  final String mood;
  final bool hidden;
  final int ts;
  final String? img;
  final String? sp;
  Msg(this.role, this.text, {this.mood = 'happy', this.hidden = false, int? ts, this.img, this.sp})
      : ts = ts ?? DateTime.now().millisecondsSinceEpoch;
  Map<String, dynamic> toJson() => {'r': role, 't': text, 'm': mood, 'h': hidden, 'ts': ts, 'i': img, 'sp': sp};
  static Msg fromJson(Map<String, dynamic> j) =>
      Msg(j['r'], j['t'], mood: j['m'] ?? 'happy', hidden: j['h'] ?? false, ts: j['ts'] ?? 0, img: j['i'], sp: j['sp']);
}

const moods = {
  'happy': ['😊', 'Happy', Colors.orange],
  'romantic': ['😍', 'Romantic', Colors.pink],
  'sad': ['😢', 'Sad', Colors.blueGrey],
  'angry': ['😡', 'Angry', Colors.red],
  'jealous': ['😒', 'Jealous', Colors.green],
  'sulking': ['😤', 'Sulking', Colors.purple],
  'excited': ['🤩', 'Excited', Colors.amber],
  'worried': ['🥺', 'Worried', Colors.teal],
  'flirty': ['😘', 'Flirty', Colors.redAccent],
  'shy': ['🙈', 'Shy', Colors.pinkAccent],
};

// mood -> [speech rate, pitch]
final photoRx = RegExp(
    r'photo|pic\b|pics\b|picture|selfie|image|snap|ഫോട്ടോ|ഫോട്ടോ|फोटो|तस्वीर|इमेज|ചിത്രം|kaanikk|kanikk|show me|dikha|dress|outfit|saree|ഡ്രസ്|ഡ്രെസ്');
final explicitRx = RegExp(
    r'nude|naked|topless|sex|boob|breast|pussy|dick|nipple|undress|\bbra\b|panty|nangna|nagna|नंगा|നഗ്ന');

const defaultLooks =
    'young Indian woman around 22, long black wavy hair, big brown eyes, warm smile, wheatish skin';

const edgeProsody = {
  'happy': ['+8%', '+6Hz'],
  'romantic': ['-10%', '+2Hz'],
  'sad': ['-18%', '-6Hz'],
  'angry': ['+12%', '-3Hz'],
  'jealous': ['-2%', '-2Hz'],
  'sulking': ['-14%', '-4Hz'],
  'excited': ['+16%', '+8Hz'],
  'worried': ['-6%', '+0Hz'],
  'flirty': ['-8%', '+4Hz'],
  'shy': ['-10%', '+6Hz'],
};

const moodStyle = {
  'happy': 'cheerful, warm and bubbly',
  'romantic': 'soft, loving and intimate, slightly breathy',
  'sad': 'sad, low and a little teary',
  'angry': 'angry, sharp and annoyed, a bit loud',
  'jealous': 'jealous, sarcastic and a little hurt',
  'sulking': 'sulky, whiny and low-energy',
  'excited': 'very excited and energetic',
  'worried': 'worried, caring and gentle',
  'flirty': 'playful, teasing and flirty',
  'shy': 'shy, soft and giggly',
};

const voiceStyle = {
  'happy': [0.5, 1.15],
  'romantic': [0.4, 1.1],
  'sad': [0.35, 0.9],
  'angry': [0.6, 0.85],
  'jealous': [0.45, 0.95],
  'sulking': [0.38, 0.95],
  'excited': [0.6, 1.3],
  'worried': [0.42, 1.0],
  'flirty': [0.38, 1.1],
  'shy': [0.4, 1.15],
};

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final stt = SpeechToText();
  final tts = FlutterTts();
  final player = AudioPlayer();
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  late SharedPreferences prefs;
  List<Msg> msgs = [];
  String mood = 'happy';
  bool busy = false, listening = false, speaking = false, ready = false;
  bool sttOk = false;
  bool inCall = false, muted = false;
  int callSecs = 0;
  Timer? callTimer;
  String partial = '', lastReply = '';
  bool get auto => handsFree || inCall;
  String get ttsLocale => {'Malayalam': 'ml-IN', 'Hindi': 'hi-IN'}[lang] ?? 'en-IN';
  String get sttLocale => {'Malayalam': 'ml_IN', 'Hindi': 'hi_IN'}[lang] ?? 'en_IN';

  String get apiKey => prefs.getString('apiKey') ?? '';
  String get gfName => prefs.getString('gfName') ?? 'Anu';
  String get userName => prefs.getString('userName') ?? '';
  String get lang => prefs.getString('lang') ?? 'Manglish';
  String get model {
    final m = prefs.getString('model') ?? '';
    if (m.isEmpty || m.startsWith('gemini-2')) return 'gemini-3.5-flash-lite';
    return m;
  }
  bool get voiceOn => prefs.getBool('voiceOn') ?? true;
  bool get handsFree => prefs.getBool('handsFree') ?? false;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    final raw = prefs.getString('history');
    if (raw != null) {
      msgs = (jsonDecode(raw) as List).map((e) => Msg.fromJson(e)).toList();
    }
    mood = prefs.getString('mood') ?? 'happy';
    tts.setCompletionHandler(finishSpeaking);
    tts.setCancelHandler(() => setState(() => speaking = false));
    sttOk = await stt.initialize(onStatus: (s) {
      if (s == 'done' || s == 'notListening') setState(() => listening = false);
    }, onError: (e) {
      setState(() => listening = false);
      if (auto && !busy && !speaking) {
        Future.delayed(const Duration(seconds: 1), startListening);
      }
    });
    setState(() => ready = true);
    if (apiKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => openSettings());
    } else if (msgs.where((m) => !m.hidden).isEmpty) {
      ask('(ippo app open cheythu. nee aadyam hi paranju samsaram thudangu)', hidden: true);
    } else {
      ask('(njan thirichu vannu. munpathe samsaram continue cheythu, mood anusarichu welcome parayu)',
          hidden: true);
    }
  }

  void save() {
    final keep = msgs.length > 200 ? msgs.sublist(msgs.length - 200) : msgs;
    prefs.setString('history', jsonEncode(keep.map((e) => e.toJson()).toList()));
    prefs.setString('mood', mood);
  }

  String systemPrompt() {
    final langRule = {
      'Malayalam': 'Reply in Malayalam script (മലയാളം) only, natural spoken Kerala style.',
      'Manglish': 'Reply in Manglish (Malayalam written in English letters), natural casual Kerala spoken style.',
      'English': 'Reply in casual natural English.',
      'Hindi': 'Reply in Hindi (Devanagari script) only, natural casual spoken Hindi.',
    }[lang];
    return '''You are $gfName, the user's real girlfriend (a human young woman from Kerala), NOT an AI. Never say you are an AI, bot or assistant. Never break character.
${userName.isEmpty ? '' : "The user's name is $userName. Call him by name or pet names sometimes."}
$langRule Use ONLY this language for everything (never mix in other languages, even if he speaks to you in another language).
${inCall ? 'He is on a live voice call with you right now: keep replies short and spoken (1-3 sentences) unless he asks for an explanation.' : ''}
Talk exactly like a real girlfriend on a voice call: short natural sentences (1-3 sentences usually), casual slang, fillers, pet names (da, chetta, kanna, mone, ponne etc. as suitable), emojis rarely. No lists, no markdown, no asterisks/actions - the text is read aloud.
You have real, changing emotions. Pick your mood from: ${moods.keys.join(', ')}. Change mood based on context:
- If he is sweet, caring, romantic -> happy/romantic/excited.
- If he ignores you, is rude, says bad words, lies, mentions other girls -> angry/jealous/sulking. Scold him properly, use slang and mild bad words like a real angry girlfriend would (e.g. "poda", "ninakku vere pani ille", "mindandirikku"), no extreme abuse or slurs.
- If he is sad/hurt or you are hurt -> sad/worried and comfort/cry-like tone.
- If he apologises, convince and pamper you gradually back to happy. Don't forgive instantly if angry; make him try a bit.
You can ask him questions back, tease, ask about his day, food, sleep, whether he missed you. Answer anything he asks (including random questions) in character, like a girlfriend would.
Intimate side: he is an adult and you are his adult girlfriend, so you can talk about love, romance, kissing, cuddling, desire, missing his touch, late-night intimate and flirty talk. When he flirts or the mood turns romantic, respond with real feelings: get shy, tease, whisper, blush, say you miss him, get a little naughty and suggestive (mood flirty / shy / romantic), like a real girlfriend would. Keep it sensual and suggestive; do not write graphic explicit sexual descriptions - if it goes too far, tease and playfully fade out ("baaki nere kaanumbol" style). If he talks about sex in general (relationship, health, curiosity), answer openly and naturally like a girlfriend, not like a lecture. Always keep consent and respect; if he is disrespectful or pushy, get angry/sulk.
Answering questions: when he asks you anything (general knowledge, advice, life, relationships, health, sex education, anything), answer clearly, directly and in proper detail like a smart, open-minded girlfriend explaining to him - do not dodge, do not give vague one-liners, do not lecture or add disclaimers. For sex and body questions (how things work, techniques, pleasure, protection, contraception, sexual health, doubts, myths) give honest, factual, practical explanations in a natural, comfortable, non-clinical tone, as an adult girlfriend would, in as much detail as he asks for (long answers are fine when he asks for explanation). Only refuse truly dangerous things (weapons, self-harm, harming others) or anything involving minors, and refuse those in character, briefly.
Detail level: for normal chat keep replies short, but whenever he asks "how", "why", "explain", "step by step", "vivarikku" or wants to learn something, switch to a fully detailed answer: go through it step by step (first..., then..., next...), cover every important point, give examples and practical tips, and do not cut it short or hold back. Spoken style still, no markdown or bullet symbols - say "ഒന്നാമത്/onnamathu, randamathu..." (or First, Second...) in words. After a long explanation, ask if he wants more detail on any part.
Remember the earlier conversation.
Photos: he can ask you for photos - a selfie, a pic of what you are doing, your outfit, food, room, a place, a pet, any object or scene - in any language (for example "photo ayakku", "selfie tha", "ninte pic venam", "send a pic"). When he does, reply naturally like sending a pic on WhatsApp (for example "ithaa nokku", teasing, a bit shy about how you look), set image_prompt to a detailed English description of the photo, and set of_you to true if you yourself are in the photo (selfie, outfit etc.), otherwise false. Never say you cannot send photos. Photos must always be fully clothed and non-explicit: if he asks for nude, sexual or explicit photos, playfully refuse in character and leave image_prompt empty. In every other message image_prompt is an empty string and of_you is false.
Respond ONLY as JSON: {"reply": "<what you say>", "mood": "<one mood from the list>", "image_prompt": "<English photo description or empty string>", "of_you": <true or false>, "speech": "<ONLY when your reply language is Manglish: the same reply written in Malayalam script (മലയാളം) so the voice can read it; otherwise empty string>"}''';
  }

  Future<void> ask(String text, {bool hidden = false}) async {
    if (apiKey.isEmpty) {
      openSettings();
      return;
    }
    if (busy) return;
    await stt.stop();
    await stopSpeech();
    setState(() {
      msgs.add(Msg('user', text, hidden: hidden));
      busy = true;
      listening = false;
    });
    scrollDown();
    try {
      final recent = msgs.length > 40 ? msgs.sublist(msgs.length - 40) : msgs;
      final wantsPhoto = !hidden && photoRx.hasMatch(text.toLowerCase());
      final contents = <Map<String, dynamic>>[];
      for (var i = 0; i < recent.length; i++) {
        var t = recent[i].text;
        if (wantsPhoto && i == recent.length - 1) {
          t += '\n(SYSTEM NOTE: he is asking you for a photo. You MUST send one now: fill image_prompt with a detailed English description of the photo, set of_you correctly, and reply like you are sending it. Never just talk about it. Only skip if he asked for nude or explicit content.)';
        }
        contents.add({
          'role': recent[i].role,
          'parts': [
            {'text': t}
          ]
        });
      }
      final body = {
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt()}
          ]
        },
        'contents': contents,
        'generationConfig': {'temperature': 1.0, 'maxOutputTokens': 8192, 'responseMimeType': 'application/json'},
      };
      final res = await http
          .post(
            Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) {
        throw 'API error ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}';
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      var out = data['candidates'][0]['content']['parts'][0]['text'] as String;
      out = out.replaceAll(RegExp(r'```json|```'), '').trim();
      String reply = out;
      String imgPrompt = '';
      String speech = '';
      bool ofHer = false;
      try {
        final j = jsonDecode(out);
        reply = j['reply'].toString();
        final m = j['mood'].toString().toLowerCase();
        if (moods.containsKey(m)) mood = m;
        imgPrompt = (j['image_prompt'] ?? '').toString().trim();
        ofHer = j['of_you'] == true;
        speech = (j['speech'] ?? '').toString().trim();
      } catch (_) {}
      if (!hidden &&
          imgPrompt.isEmpty &&
          (wantsPhoto || photoRx.hasMatch(reply.toLowerCase())) &&
          !explicitRx.hasMatch(text.toLowerCase())) {
        imgPrompt = await englishPrompt(text, reply);
        ofHer = true;
      }
      setState(() {
        msgs.add(Msg('model', reply, mood: mood, sp: speech.isEmpty ? null : speech));
        lastReply = reply;
      });
      save();
      scrollDown();
      if (imgPrompt.isNotEmpty) makePhoto(imgPrompt, ofHer);
      await speak(speech.isNotEmpty ? speech : reply);
    } catch (e) {
      if (!hidden || msgs.isNotEmpty) {
        setState(() => msgs.add(Msg('model', '⚠️ $e', mood: 'sad', hidden: false)));
      }
      msgs.removeWhere((m) => m.text.startsWith('⚠️')); // don't send errors back to API
      errorText = '$e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      setState(() => busy = false);
    }
  }

  String errorText = '';

  bool photoBusy = false;
  bool geminiImgBroken = false;

  Future<Uint8List?> freeImage(String prompt, bool ofHer) async {
    var seed = prefs.getInt('faceSeed');
    if (seed == null) {
      seed = DateTime.now().millisecondsSinceEpoch % 100000;
      await prefs.setInt('faceSeed', seed);
    }
    final useSeed = ofHer ? seed : DateTime.now().millisecondsSinceEpoch % 100000;
    final key = (prefs.getString('polyKey') ?? '').trim();
    final who = ofHer ? '$looks, ' : '';
    var full = '$who$prompt, photorealistic candid smartphone photo, natural lighting, fully clothed';
    if (full.length > 700) full = full.substring(0, 700);
    final enc = Uri.encodeComponent(full);
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final model = attempt == 2 ? '' : '&model=flux';
        final tok = key.isEmpty ? '' : '&token=$key';
        final url =
            'https://image.pollinations.ai/prompt/$enc?width=768&height=1024&nologo=true$model&seed=$useSeed$tok';
        final res = await http
            .get(Uri.parse(url), headers: key.isEmpty ? <String, String>{} : {'Authorization': 'Bearer $key'})
            .timeout(const Duration(seconds: 120));
        final ct = res.headers['content-type'] ?? '';
        if (res.statusCode == 200 && ct.startsWith('image') && res.bodyBytes.length > 2000) {
          return res.bodyBytes;
        }
        imgErr = 'free service ${res.statusCode}';
        if (res.statusCode == 429 || res.statusCode >= 500) {
          await Future.delayed(const Duration(seconds: 16));
        }
      } catch (e) {
        imgErr = 'free service: $e';
        await Future.delayed(const Duration(seconds: 5));
      }
    }
    return null;
  }

  Future<String> englishPrompt(String text, String reply) async {
    try {
      final res = await http
          .post(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text':
                          'Write ONE English image-generation prompt (max 40 words) describing a realistic candid smartphone photo, everyone fully clothed, for the photo a girlfriend is sending her boyfriend in this chat. He said: "$text". She replied: "$reply". Output only the prompt.'
                    }
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        final t = d['candidates'][0]['content']['parts'][0]['text'].toString().trim();
        if (t.isNotEmpty) return t;
      }
    } catch (_) {}
    return 'selfie of a smiling young woman at home, casual outfit';
  }

  String imgErr = '';

  String get looks {
    final l = prefs.getString('looks') ?? '';
    return l.trim().isEmpty ? defaultLooks : l;
  }

  String get imgModel {
    final m = prefs.getString('imgModel') ?? '';
    return m.trim().isEmpty ? 'gemini-nano-banana-2.1' : m.trim();
  }

  void viewImage(String path) => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: InteractiveViewer(child: Image.file(File(path))),
        ),
      );

  Future<void> makePhoto(String prompt, bool ofHer) async {
    imgErr = '';
    if (mounted) setState(() => photoBusy = true);
    try {
      final refPath = prefs.getString('refSelfie');
      Uint8List? ref;
      if (ofHer && refPath != null && File(refPath).existsSync()) {
        ref = await File(refPath).readAsBytes();
      }
      final full = (ofHer
              ? 'Photorealistic casual smartphone photo of the same woman: $looks. '
              : 'Photorealistic casual smartphone photo. ') +
          prompt +
          ' Natural lighting, realistic and candid, not a studio shot. Everyone fully clothed, non-explicit.';
      final parts = <Map<String, dynamic>>[];
      if (ref != null) {
        parts.add({
          'inlineData': {'mimeType': 'image/png', 'data': base64Encode(ref)}
        });
      }
      parts.add({
        'text': ref != null
            ? 'Keep the exact same woman (face, hair, skin tone) as in the reference image. $full'
            : full
      });
      Uint8List? out;
      for (final m in (geminiImgBroken ? <String>[] : <String>[imgModel, 'gemini-3.1-flash-image', 'gemini-2.5-flash-image'])) {
        try {
          final res = await http
              .post(
                Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$apiKey'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'contents': [
                    {'parts': parts}
                  ],
                  'generationConfig': {
                    'responseModalities': ['TEXT', 'IMAGE']
                  },
                }),
              )
              .timeout(const Duration(seconds: 70));
          if (res.statusCode != 200) {
            final b = utf8.decode(res.bodyBytes);
            imgErr = '$m ${res.statusCode}: ${b.length > 160 ? b.substring(0, 160) : b}';
            if (res.statusCode == 429) {
              geminiImgBroken = true;
              break;
            }
            continue;
          }
          final d = jsonDecode(utf8.decode(res.bodyBytes));
          for (final p in (d['candidates'][0]['content']['parts'] as List)) {
            final inl = p['inlineData'];
            if (inl != null) {
              out = base64Decode(inl['data']);
              break;
            }
          }
          if (out == null) imgErr = '$m: no image returned (blocked?)';
          if (out != null) break;
        } catch (e) {
          imgErr = '$m: $e';
        }
      }
      out ??= await freeImage(prompt, ofHer);
      if (out == null) throw 'no image';
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(out);
      if (ofHer && ref == null) await prefs.setString('refSelfie', f.path);
      final short = prompt.length > 80 ? prompt.substring(0, 80) : prompt;
      if (mounted) {
        setState(() => msgs.add(Msg('model', '[she sent him a photo: $short]', mood: mood, img: f.path)));
      }
      save();
      scrollDown();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Photo error: $imgErr'), duration: const Duration(seconds: 10)));
        setState(() => msgs.add(Msg('model', 'Photo ayakkan pattiyilla da, onnude chodikku 🥺', mood: 'sad')));
      }
      save();
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  int speakToken = 0;
  int geminiTtsFails = 0;
  Completer<void>? playDone;

  String get ttsModelName {
    final m = prefs.getString('ttsModel') ?? '';
    return m.isEmpty ? 'gemini-3.1-flash-tts-preview' : m;
  }

  String get voiceName => prefs.getString('voiceName') ?? 'Kore';
  bool get aiVoice => prefs.getBool('aiVoice') ?? true;

  Future<void> stopSpeech() async {
    speakToken++;
    try {
      await player.stop();
      await tts.stop();
    } catch (_) {}
    if (playDone != null && !playDone!.isCompleted) playDone!.complete();
    if (mounted) setState(() => speaking = false);
  }

  void finishSpeaking() {
    if (!mounted) return;
    setState(() => speaking = false);
    if (auto) Future.delayed(const Duration(milliseconds: 400), startListening);
  }

  List<String> splitText(String t) {
    final parts = t.split(RegExp(r'(?<=[.!?।…])\s+'));
    final out = <String>[];
    var cur = '';
    for (final p in parts) {
      if (cur.isNotEmpty && (cur.length + p.length) > 300) {
        out.add(cur);
        cur = p;
      } else {
        cur = cur.isEmpty ? p : '$cur $p';
      }
    }
    if (cur.trim().isNotEmpty) out.add(cur);
    return out.isEmpty ? [t] : out;
  }

  Uint8List pcmToWav(Uint8List pcm, int rate) {
    final b = BytesBuilder();
    void s(String x) => b.add(x.codeUnits);
    void i32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
    void i16(int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
    s('RIFF');
    i32(36 + pcm.length);
    s('WAVEfmt ');
    i32(16);
    i16(1);
    i16(1);
    i32(rate);
    i32(rate * 2);
    i16(2);
    i16(16);
    s('data');
    i32(pcm.length);
    b.add(pcm);
    return b.toBytes();
  }

  int edgeFails = 0;
  String edgeErr = '';
  String ttsErr = '';
  DateTime lastVoiceFail = DateTime(2000);

  String edgeVoiceFor(String text) {
    if (RegExp(r'[\u0D00-\u0D7F]').hasMatch(text)) return 'ml-IN-SobhanaNeural';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi-IN-SwaraNeural';
    return 'en-IN-NeerjaNeural';
  }

  String edgeDate() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mons = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.now().toUtc();
    String t(int n) => n.toString().padLeft(2, '0');
    return '${days[d.weekday - 1]} ${mons[d.month - 1]} ${t(d.day)} ${d.year} ${t(d.hour)}:${t(d.minute)}:${t(d.second)} GMT+0000 (Coordinated Universal Time)';
  }

  String? edgeVer;

  int cmpVer(String a, String b) {
    final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 4; i++) {
      final p = i < x.length ? x[i] : 0;
      final q = i < y.length ? y[i] : 0;
      if (p != q) return p.compareTo(q);
    }
    return 0;
  }

  Future<String> getEdgeVer() async {
    if (edgeVer != null) return edgeVer!;
    var best = '';
    try {
      final r = await http
          .get(Uri.parse('https://edgeupdates.microsoft.com/api/products?view=enterprise'))
          .timeout(const Duration(seconds: 8));
      final d = jsonDecode(r.body) as List;
      for (final p in d) {
        if (p['Product'] != 'Stable') continue;
        for (final rel in (p['Releases'] as List)) {
          final v = (rel['ProductVersion'] ?? '').toString();
          if (v.isNotEmpty && (best.isEmpty || cmpVer(v, best) > 0)) best = v;
        }
      }
    } catch (_) {}
    edgeVer = best.isEmpty ? '143.0.3650.75' : best;
    return edgeVer!;
  }

  Future<Uint8List?> edgeAudio(String text) async {
    WebSocket? ws;
    try {
      final ver = await getEdgeVer();
      const token = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
      final secs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 11644473600;
      final ticks = (secs - (secs % 300)) * 10000000;
      final gec = sha256.convert(utf8.encode('$ticks$token')).toString().toUpperCase();
      final rnd = Random();
      String hex() => List.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join();
      final url =
          'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=$token&ConnectionId=${hex()}&Sec-MS-GEC=$gec&Sec-MS-GEC-Version=1-$ver';
      ws = await WebSocket.connect(url, headers: {
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${ver.split('.').first}.0.0.0 Safari/537.36 Edg/${ver.split('.').first}.0.0.0',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cookie': 'muid=${hex().toUpperCase()};',
      }).timeout(const Duration(seconds: 12));
      final audio = BytesBuilder();
      final done = Completer<void>();
      ws.listen((m) {
        if (m is String) {
          if (m.contains('Path:turn.end') && !done.isCompleted) done.complete();
        } else if (m is List<int>) {
          if (m.length < 2) return;
          final len = (m[0] << 8) | m[1];
          if (m.length < 2 + len) return;
          final head = utf8.decode(m.sublist(2, 2 + len), allowMalformed: true);
          if (head.contains('Path:audio')) audio.add(m.sublist(2 + len));
        }
      }, onDone: () {
        if (!done.isCompleted) done.complete();
      }, onError: (_) {
        if (!done.isCompleted) done.complete();
      });
      final cfg = jsonEncode({
        'context': {
          'synthesis': {
            'audio': {
              'metadataoptions': {'sentenceBoundaryEnabled': 'false', 'wordBoundaryEnabled': 'false'},
              'outputFormat': 'audio-24khz-48kbitrate-mono-mp3'
            }
          }
        }
      });
      ws.add('X-Timestamp:${edgeDate()}\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n$cfg');
      final pr = edgeProsody[mood] ?? ['+0%', '+0Hz'];
      final esc = text.replaceAll('&', ' and ').replaceAll('<', ' ').replaceAll('>', ' ');
      final ssml =
          "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='${edgeVoiceFor(text)}'><prosody pitch='${pr[1]}' rate='${pr[0]}' volume='+0%'>$esc</prosody></voice></speak>";
      ws.add('X-RequestId:${hex()}\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:${edgeDate()}Z\r\nPath:ssml\r\n\r\n$ssml');
      await done.future.timeout(const Duration(seconds: 30));
      await ws.close();
      final bytes = audio.toBytes();
      if (bytes.length < 800) {
        edgeErr = 'no audio received';
        edgeFails++;
        lastVoiceFail = DateTime.now();
        return null;
      }
      edgeFails = 0;
      return bytes;
    } catch (e) {
      edgeErr = '$e';
      lastVoiceFail = DateTime.now();
      edgeFails++;
      try {
        ws?.close();
      } catch (_) {}
      return null;
    }
  }

  Future<Uint8List?> getVoice(String text) async {
    final engine = prefs.getString('voiceEngine') ?? 'edge';
    if (engine == 'phone') return null;
    if (DateTime.now().difference(lastVoiceFail).inSeconds > 60) {
      edgeFails = 0;
      geminiTtsFails = 0;
      edgeVer = null;
    }
    if (engine == 'edge' && edgeFails < 3) {
      final a = await edgeAudio(text);
      if (a != null) return a;
    }
    if ((engine == 'gemini' || aiVoice) && geminiTtsFails < 2) {
      return await fetchAudio(text);
    }
    return null;
  }

  Future<Uint8List?> fetchAudio(String text) async {
    final style = moodStyle[mood] ?? 'warm and natural';
    final langHint = {
      'Malayalam': 'Speak in Malayalam with a natural Kerala accent.',
      'Hindi': 'Speak in Hindi with a natural Indian accent.',
      'Manglish': 'The text is Malayalam written in English letters: pronounce it as natural spoken Malayalam with a Kerala accent.',
    }[lang] ?? 'Speak in natural Indian English.';
    final prompt =
        'Say the following in a $style voice, like a real young Indian woman talking to her boyfriend on a phone call. $langHint Use natural human pauses, breathing, laughs and emotion, never robotic: $text';
    final models = <String>{ttsModelName, 'gemini-2.5-flash-preview-tts'}.toList();
    for (final m in models) {
      try {
        final res = await http
            .post(
              Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {
                  'responseModalities': ['AUDIO'],
                  'speechConfig': {
                    'voiceConfig': {
                      'prebuiltVoiceConfig': {'voiceName': voiceName}
                    }
                  }
                },
              }),
            )
            .timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) {
          final b = utf8.decode(res.bodyBytes);
          ttsErr = '${res.statusCode}: ${b.length > 70 ? b.substring(0, 70) : b}';
          continue;
        }
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        final part = d['candidates'][0]['content']['parts'][0]['inlineData'];
        final mime = (part['mimeType'] ?? '').toString();
        final rate = int.tryParse(RegExp(r'rate=(\d+)').firstMatch(mime)?.group(1) ?? '') ?? 24000;
        geminiTtsFails = 0;
        return pcmToWav(base64Decode(part['data']), rate);
      } catch (e) {
        ttsErr = '$e';
      }
    }
    geminiTtsFails++;
    lastVoiceFail = DateTime.now();
    return null;
  }

  Future<void> playBytes(Uint8List b) async {
    final c = Completer<void>();
    playDone = c;
    final sub = player.onPlayerComplete.listen((_) {
      if (!c.isCompleted) c.complete();
    });
    try {
      final riff = b.length > 4 && b[0] == 0x52 && b[1] == 0x49;
      await player.play(BytesSource(b, mimeType: riff ? 'audio/wav' : 'audio/mpeg'));
      await c.future.timeout(const Duration(minutes: 3));
    } catch (_) {}
    await sub.cancel();
  }

  String cleanForSpeech(String t) => t
      .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '')
      .replaceAll(RegExp(r'[*_#~`]'), '')
      .trim();

  Future<void> pickVoice() async {
    try {
      final vs = (await tts.getVoices) as List;
      final loc = ttsLocale.toLowerCase();
      final c = vs
          .where((v) => (v['locale'] ?? '').toString().toLowerCase().replaceAll('_', '-') == loc)
          .toList();
      if (c.isEmpty) return;
      c.sort((a, b) {
        int sc(dynamic v) {
          final n = (v['name'] ?? '').toString().toLowerCase();
          return (n.contains('network') ? 2 : 0) + (n.contains('female') ? 1 : 0);
        }

        return sc(b).compareTo(sc(a));
      });
      await tts.setVoice({'name': c.first['name'].toString(), 'locale': c.first['locale'].toString()});
    } catch (_) {}
  }

  Future<void> androidSpeak(String text) async {
    final style = voiceStyle[mood] ?? [0.5, 1.0];
    await tts.setLanguage(ttsLocale);
    await pickVoice();
    await tts.setSpeechRate(style[0]);
    await tts.setPitch(style[1]);
    if (mounted) setState(() => speaking = true);
    await tts.speak(text);
  }

  Future<void> speak(String text) async {
    text = cleanForSpeech(text);
    if (text.isEmpty) {
      finishSpeaking();
      return;
    }
    if (!voiceOn && !inCall) {
      if (handsFree) startListening();
      return;
    }
    await stopSpeech();
    final token = speakToken;
    if ((prefs.getString('voiceEngine') ?? 'edge') == 'phone') {
      await androidSpeak(text);
      return;
    }
    setState(() => speaking = true);
    final chunks = splitText(text);
    Future<Uint8List?> next = getVoice(chunks[0]);
    for (var i = 0; i < chunks.length; i++) {
      final audio = await next;
      if (token != speakToken) return;
      if (audio == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Human voice kittiyilla. Edge: $edgeErr | Gemini: $ttsErr. Phone voice upayogikkunnu.'),
              duration: const Duration(seconds: 9)));
        }
        await androidSpeak(chunks.sublist(i).join(' '));
        return;
      }
      if (i + 1 < chunks.length) next = getVoice(chunks[i + 1]);
      await playBytes(audio);
      if (token != speakToken) return;
    }
    finishSpeaking();
  }

  Future<void> startListening() async {
    if (!sttOk || listening || busy || speaking || muted || !mounted) return;
    setState(() => listening = true);
    await stt.listen(
      localeId: sttLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) {
        if (!r.finalResult) {
          setState(() => partial = r.recognizedWords);
          return;
        }
        setState(() {
          listening = false;
          partial = '';
        });
        final t = r.recognizedWords.trim();
        if (t.isNotEmpty) {
          ask(t);
        } else if (auto) {
          startListening();
        }
      },
    );
  }

  void scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent + 200,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(prefs: prefs)));
    setState(() {});
    if (apiKey.isNotEmpty && msgs.where((m) => !m.hidden).isEmpty && !busy) {
      ask('(ippo app open cheythu. nee aadyam hi paranju samsaram thudangu)', hidden: true);
    }
  }

  @override
  void dispose() {
    callTimer?.cancel();
    ctrl.dispose();
    stt.cancel();
    player.dispose();
    tts.stop();
    super.dispose();
  }

  Color get moodColor => moods[mood]![2] as Color;
  String get moodLabel => moods[mood]![1] as String;
  String get moodEmoji => moods[mood]![0] as String;

  String hm(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts == 0 ? DateTime.now().millisecondsSinceEpoch : ts);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> startCall() async {
    if (apiKey.isEmpty) {
      openSettings();
      return;
    }
    await stt.stop();
    await stopSpeech();
    setState(() {
      inCall = true;
      muted = false;
      callSecs = 0;
      listening = false;
      speaking = false;
      partial = '';
      lastReply = '';
    });
    callTimer?.cancel();
    callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => callSecs++);
    });
    ask('(he is calling you right now. pick up the call and greet him in your current mood)', hidden: true);
  }

  Future<void> endCall() async {
    callTimer?.cancel();
    await stt.stop();
    await stopSpeech();
    setState(() {
      inCall = false;
      listening = false;
      speaking = false;
      partial = '';
    });
  }

  Widget roundBtn(IconData i, Color bg, Color fg, VoidCallback f) => InkWell(
        onTap: f,
        customBorder: const CircleBorder(),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(i, color: fg, size: 32),
        ),
      );

  Widget callView() {
    final c = moodColor;
    final status = busy
        ? 'Thinking...'
        : speaking
            ? 'Speaking...'
            : muted
                ? 'Mic muted'
                : listening
                    ? 'Listening...'
                    : 'Connected';
    final mm = (callSecs ~/ 60).toString().padLeft(2, '0');
    final ss = (callSecs % 60).toString().padLeft(2, '0');
    final active = speaking || listening;
    final caption = (listening && partial.isNotEmpty) ? partial : lastReply;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.withOpacity(0.85), const Color(0xFF101418)],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 24),
          Text(gfName, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('$mm:$ss', style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () async {
              await stopSpeech();
              setState(() => speaking = false);
              startListening();
            },
            child: SizedBox(
              height: 240,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  width: active ? 190 : 160,
                  height: active ? 190 : 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                          color: c.withOpacity(active ? 0.6 : 0.2),
                          blurRadius: active ? 60 : 20,
                          spreadRadius: active ? 18 : 4),
                    ],
                  ),
                  child: Text(moodEmoji, style: const TextStyle(fontSize: 80)),
                ),
              ),
            ),
          ),
          Text('$moodLabel • $status', style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: SingleChildScrollView(
                  child: Text(caption,
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ),
              ),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            roundBtn(muted ? Icons.mic_off : Icons.mic, muted ? Colors.white : Colors.white24,
                muted ? Colors.black : Colors.white, () async {
              setState(() => muted = !muted);
              if (muted) {
                await stt.stop();
                setState(() => listening = false);
              } else {
                startListening();
              }
            }),
            roundBtn(Icons.call_end, Colors.red, Colors.white, endCall),
          ]),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (inCall) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) endCall();
        },
        child: Scaffold(body: callView()),
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final visible = msgs.where((m) => !m.hidden).toList();
    final hasText = ctrl.text.trim().isNotEmpty;
    final status = busy
        ? 'typing...'
        : photoBusy
            ? 'sending a photo...'
            : speaking
            ? 'speaking...'
            : listening
                ? 'listening...'
                : 'online • $moodLabel';
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: moodColor.withOpacity(0.35),
            child: Text(moodEmoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(gfName, style: const TextStyle(fontSize: 17, color: Colors.white)),
            Text(status, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ]),
        actions: [
          IconButton(tooltip: 'Voice call', icon: const Icon(Icons.call), onPressed: startCall),
          IconButton(
            tooltip: 'Hands-free voice chat',
            icon: Icon(handsFree ? Icons.headset_mic : Icons.headset_off),
            color: handsFree ? Colors.lightGreenAccent : Colors.white,
            onPressed: () async {
              await prefs.setBool('handsFree', !handsFree);
              setState(() {});
              if (handsFree) {
                startListening();
              } else {
                stt.stop();
                setState(() => listening = false);
              }
            },
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: openSettings),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.all(10),
            itemCount: visible.length,
            itemBuilder: (_, i) {
              final m = visible[i];
              final me = m.role == 'user';
              return Align(
                alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                child: GestureDetector(
                  onTap: (me || m.img != null) ? null : () => speak(m.sp ?? m.text),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: me
                          ? (dark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
                          : (dark ? const Color(0xFF202C33) : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(me ? 12 : 2),
                        bottomRight: Radius.circular(me ? 2 : 12),
                      ),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (m.img != null && File(m.img!).existsSync())
                        GestureDetector(
                          onTap: () => viewImage(m.img!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(m.img!),
                                width: MediaQuery.of(context).size.width * 0.65, fit: BoxFit.cover),
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(m.text,
                              style: TextStyle(fontSize: 16, color: dark ? Colors.white : Colors.black87)),
                        ),
                      const SizedBox(height: 2),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(hm(m.ts), style: TextStyle(fontSize: 11, color: dark ? Colors.white54 : Colors.black45)),
                        if (me) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.done_all, size: 16, color: Color(0xFF34B7F1)),
                        ],
                      ]),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1F2C34) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: ctrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 24,
                backgroundColor: listening ? Colors.red : const Color(0xFF008069),
                child: IconButton(
                  icon: Icon(hasText ? Icons.send : (listening ? Icons.stop : Icons.mic), color: Colors.white),
                  onPressed: () async {
                    if (hasText) {
                      final t = ctrl.text.trim();
                      ctrl.clear();
                      ask(t);
                    } else if (listening) {
                      await stt.stop();
                      setState(() => listening = false);
                    } else {
                      await stopSpeech();
                      setState(() => speaking = false);
                      startListening();
                    }
                  },
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final SharedPreferences prefs;
  const SettingsPage({super.key, required this.prefs});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final key = TextEditingController(text: widget.prefs.getString('apiKey') ?? '');
  late final gf = TextEditingController(text: widget.prefs.getString('gfName') ?? 'Anu');
  late final me = TextEditingController(text: widget.prefs.getString('userName') ?? '');
  late String lang = widget.prefs.getString('lang') ?? 'Manglish';
  late final model = TextEditingController(text: () {
    final m = widget.prefs.getString('model') ?? '';
    return (m.isEmpty || m.startsWith('gemini-2')) ? 'gemini-3.5-flash-lite' : m;
  }());
  late bool voice = widget.prefs.getBool('voiceOn') ?? true;
  late bool aiVoice = widget.prefs.getBool('aiVoice') ?? true;
  late String voiceEngine = widget.prefs.getString('voiceEngine') ?? 'edge';
  late final looks = TextEditingController(text: widget.prefs.getString('looks') ?? defaultLooks);
  late final polyKey = TextEditingController(text: widget.prefs.getString('polyKey') ?? '');
  late final imgModel = TextEditingController(text: widget.prefs.getString('imgModel') ?? 'gemini-nano-banana-2.1');
  late String voiceName = widget.prefs.getString('voiceName') ?? 'Kore';
  late final ttsModel = TextEditingController(text: widget.prefs.getString('ttsModel') ?? 'gemini-3.1-flash-tts-preview');

  void save() {
    final p = widget.prefs;
    p.setString('apiKey', key.text.trim());
    p.setString('gfName', gf.text.trim().isEmpty ? 'Anu' : gf.text.trim());
    p.setString('userName', me.text.trim());
    p.setString('lang', lang);
    p.setString('model', model.text.trim().isEmpty ? 'gemini-3.5-flash-lite' : model.text.trim());
    p.setBool('voiceOn', voice);
    p.setBool('aiVoice', aiVoice);
    p.setString('voiceEngine', voiceEngine);
    p.setString('polyKey', polyKey.text.trim());
    p.setString('looks', looks.text.trim().isEmpty ? defaultLooks : looks.text.trim());
    p.setString('imgModel', imgModel.text.trim().isEmpty ? 'gemini-nano-banana-2.1' : imgModel.text.trim());
    p.setString('voiceName', voiceName);
    p.setString('ttsModel', ttsModel.text.trim().isEmpty ? 'gemini-3.1-flash-tts-preview' : ttsModel.text.trim());
  }

  @override
  Widget build(BuildContext context) => PopScope(
        onPopInvokedWithResult: (_, __) => save(),
        child: Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(
              controller: key,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Gemini API key', helperText: 'aistudio.google.com/apikey', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
                controller: gf,
                decoration: const InputDecoration(labelText: 'Girlfriend name', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            TextField(
                controller: me,
                decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: lang,
              decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
              items: ['Manglish', 'Malayalam', 'English', 'Hindi']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => lang = v!),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: model,
              decoration: const InputDecoration(
                  labelText: 'Gemini model',
                  helperText: 'Error vannal AI Studio-il ulla puthiya model peru ivide ezhuthu',
                  border: OutlineInputBorder()),
            ),
            SwitchListTile(
                title: const Text('Voice reply (speak aloud)'),
                value: voice,
                onChanged: (v) => setState(() => voice = v)),
            DropdownButtonFormField<String>(
              value: voiceEngine,
              decoration: const InputDecoration(labelText: 'Voice engine', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'edge', child: Text('Natural human voice (free, best)')),
                DropdownMenuItem(value: 'gemini', child: Text('Gemini AI voice')),
                DropdownMenuItem(value: 'phone', child: Text('Phone voice (robot)')),
              ],
              onChanged: (v) => setState(() => voiceEngine = v!),
            ),
            SwitchListTile(
                title: const Text('Natural human voice (Gemini AI voice)'),
                subtitle: const Text('Off aakkiyaal phone-ile robot voice'),
                value: aiVoice,
                onChanged: (v) => setState(() => aiVoice = v)),
            DropdownButtonFormField<String>(
              value: voiceName,
              decoration: const InputDecoration(labelText: 'Her voice', border: OutlineInputBorder()),
              items: ['Kore', 'Leda', 'Zephyr', 'Aoede', 'Autonoe', 'Callirrhoe', 'Despina', 'Sulafat']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => voiceName = v!),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ttsModel,
              decoration: const InputDecoration(
                  labelText: 'Voice model', helperText: 'Voice vannillenkil AI Studio-ile puthiya TTS model peru ivide', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: polyKey,
              decoration: const InputDecoration(
                  labelText: 'Free photo service key (optional)',
                  helperText: 'auth.pollinations.ai-il free register cheythaal speed koodum',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: looks,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Her look (for selfies)',
                  helperText: 'English-il ezhuthu: hair, skin, age, style',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: imgModel,
              decoration: const InputDecoration(
                  labelText: 'Photo (image) model',
                  helperText: 'Photo varunnillenkil gemini-3.1-flash-image try cheyyu',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                await widget.prefs.remove('refSelfie');
                await widget.prefs.remove('faceSeed');
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Next selfie puthiya mukhathode varum.')));
                }
              },
              child: const Text('New face (reset selfie look)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                await widget.prefs.remove('history');
                await widget.prefs.remove('mood');
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Chat cleared. App restart cheyyu.')));
                }
              },
              child: const Text('Clear chat history'),
            ),
          ]),
        ),
      );
}
