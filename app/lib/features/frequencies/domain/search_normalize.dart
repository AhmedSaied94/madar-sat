/// Search folding for S5, the same rules as the server's `ar_normalize` (so the app and
/// `/v1/satellites/{id}/channels?q=` agree) plus what a Latin keyboard adds: lower case, no
/// accents, and Arabic-Indic digits read as Western ones.
///
/// Both the query and the text it is matched against go through this, so «الأهلي» finds
/// «الاهلي», `Café` finds `cafe`, and `7.0W` finds `7 0w`.
String normalizeSearch(String? text) {
  if (text == null || text.isEmpty) return '';
  final out = StringBuffer();
  var lastWasSpace = true;
  void space() {
    if (!lastWasSpace) out.write(' ');
    lastWasSpace = true;
  }

  for (final rune in text.toLowerCase().runes) {
    final folded = _fold(rune);
    if (folded == null) continue;
    if (folded == ' ') {
      space();
    } else {
      out.write(folded);
      lastWasSpace = false;
    }
  }
  return out.toString().trim();
}

/// What one character becomes: itself, another character, a space (punctuation and
/// whitespace) or null (a mark that is dropped).
String? _fold(int rune) {
  if (_isTashkeel(rune)) return null;
  if (rune >= _arabicIndicZero && rune <= _arabicIndicZero + 9) {
    return String.fromCharCode(_asciiZero + rune - _arabicIndicZero);
  }
  if (rune >= _extendedIndicZero && rune <= _extendedIndicZero + 9) {
    return String.fromCharCode(_asciiZero + rune - _extendedIndicZero);
  }
  final latin = _latinFold[rune];
  if (latin != null) return latin;
  final arabic = _arabicFold[rune];
  if (arabic != null) return arabic;
  if (_isPunctuation(rune) || _isWhitespace(rune)) return ' ';
  return String.fromCharCode(rune);
}

const int _asciiZero = 0x30;
const int _arabicIndicZero = 0x0660;
const int _extendedIndicZero = 0x06F0;

/// Fatha to sukun, the dagger alif and the tatweel.
bool _isTashkeel(int rune) =>
    (rune >= 0x064B && rune <= 0x0652) || rune == 0x0670 || rune == 0x0640;

bool _isWhitespace(int rune) => rune == 0x20 || (rune >= 0x09 && rune <= 0x0D);

/// ASCII punctuation, Latin-1 symbols, Arabic punctuation, general punctuation and arrows:
/// the ranges `ar_normalize` turns into spaces. Digits and letters are not in them.
bool _isPunctuation(int rune) =>
    (rune >= 0x21 && rune <= 0x2F) ||
    (rune >= 0x3A && rune <= 0x40) ||
    (rune >= 0x5B && rune <= 0x60) ||
    (rune >= 0x7B && rune <= 0x7E) ||
    (rune >= 0xA0 && rune <= 0xBF) ||
    rune == 0xD7 ||
    rune == 0xF7 ||
    rune == 0x060C ||
    rune == 0x061B ||
    rune == 0x061F ||
    (rune >= 0x066A && rune <= 0x066D) ||
    rune == 0x06D4 ||
    (rune >= 0x2000 && rune <= 0x206F) ||
    (rune >= 0x2190 && rune <= 0x2BFF);

/// أ إ آ ٱ → ا · ة → ه · ى ئ → ي · ؤ → و.
final Map<int, String> _arabicFold = {
  for (final rune in 'أإآٱ'.runes) rune: 'ا',
  for (final rune in 'ة'.runes) rune: 'ه',
  for (final rune in 'ىئ'.runes) rune: 'ي',
  for (final rune in 'ؤ'.runes) rune: 'و',
};

/// Accented Latin letters → the plain letter (the query is already lower case).
final Map<int, String> _latinFold = () {
  const groups = <String, String>{
    'a': 'àáâãäåāăą',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįı',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņň',
    'o': 'òóôõöøōŏő',
    'r': 'ŕŗř',
    's': 'śŝşš',
    't': 'ţťŧ',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
  };
  return {
    for (final entry in groups.entries)
      for (final rune in entry.value.runes) rune: entry.key,
    'ß'.runes.first: 'ss',
  };
}();
