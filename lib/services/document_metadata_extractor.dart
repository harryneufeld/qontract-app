import 'document_text_line.dart';

class DocumentDateEvidence {
  final DateTime date;
  final String passage;
  final int priority;
  const DocumentDateEvidence(this.date, this.passage, this.priority);
}

class DocumentNumberEvidence {
  final String number;
  final String passage;
  const DocumentNumberEvidence(this.number, this.passage);
}

class DocumentMetadataSuggestion {
  final String? subject;
  final String? subjectPassage;
  final DateTime? date;
  final List<DocumentDateEvidence> dates;
  final List<DocumentNumberEvidence> numbers;
  String? get contractNumber =>
      numbers.length == 1 ? numbers.single.number : null;
  const DocumentMetadataSuggestion(
      {this.subject,
      this.subjectPassage,
      this.date,
      this.dates = const [],
      this.numbers = const []});
}

/// Local, conservative suggestions. Due dates and coverage periods are not
/// document dates; equally likely conflicting dates require a user choice.
class DocumentMetadataExtractor {
  static final _subject = RegExp(
      r'^\s*(?:betreff|subject|re)(?:\s*[:：–-]\s*|\s+|$)(.*)$',
      caseSensitive: false);
  static final _heading = RegExp(
      r'\b(?:rechnung|invoice|beitragsrechnung|jahresabrechnung|abrechnung|beitragsanpassung|beitragserhöhung|beitragserhoehung|vertragsänderung|vertragsaenderung|vertragsbestätigung|vertragsbestaetigung|versicherungsschein|kündigungsbestätigung|kuendigungsbestaetigung|zahlungserinnerung|mahnung|nachtrag|gutschrift|rückerstattung|rueckerstattung|bestätigung|bestaetigung|payment notice|renewal notice|contract confirmation|annual statement|premium adjustment|premium increase|credit note|payment reminder|policy renewal)\b',
      caseSensitive: false);
  static final _salutation = RegExp(
      r'^(?:sehr geehrt|liebe[rn]?\b|guten tag|dear\b|hello\b|mit freundlichen|kind regards|yours)',
      caseSensitive: false);

  static String? _shortSubject(String source) {
    source = source.replaceFirst(
        RegExp(r'^\s*(?:subject|betreff|re)\s*[:：–-]\s*', caseSensitive: false),
        '');
    final numberLabelMatch = numberLabel.firstMatch(source);
    if (numberLabelMatch != null) {
      source = source.substring(0, numberLabelMatch.start);
    }
    final value = source
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^[•*–-]+\s*'), '');
    if (value.length < 3 ||
        !RegExp(r'[a-zäöüß]{3}', caseSensitive: false).hasMatch(value) ||
        _salutation.hasMatch(value) ||
        unrelatedNumberLabel.hasMatch(value)) {
      return null;
    }
    final words = value.split(' ');
    var short = words.take(10).join(' ');
    if (short.length > 72) {
      short = short.substring(0, 72);
      final space = short.lastIndexOf(' ');
      if (space >= 35) short = short.substring(0, space);
    }
    return short.length < value.length ? '${short.trimRight()}…' : short;
  }

  static final _documentLabel = RegExp(
      r'\b(?:rechnungsdatum|belegdatum|ausstellungsdatum|dokumentdatum|briefdatum|invoice date|document date|issue date|date of issue|erstellt am|ausgestellt am|schreibendatum)\b',
      caseSensitive: false);
  static final _dateLabel = RegExp(r'\b(?:datum|date)\b', caseSensitive: false);
  static final _otherDate = RegExp(
      r'\b(?:fällig\w*|faellig\w*|zahlbar|due|payment deadline|gültig\w*|gueltig\w*|wirksam\w*|effective|beginn|begin|start|ende|end|bis|zeitraum|period|geburt\w*|birth\w*|vertragsbeginn|vertragsende|versicherungsbeginn|versicherungsende|leistungsdatum|lieferdatum|delivery date|service date|renewal date|ablauf|ablaufdatum|kündigung|kuendigung|mahnfrist|zahlungsziel|zahlungsdatum|payment date|expiry|expiration)\b',
      caseSensitive: false);
  static const _months = {
    'january': 1,
    'jan': 1,
    'januar': 1,
    'february': 2,
    'feb': 2,
    'februar': 2,
    'march': 3,
    'mar': 3,
    'märz': 3,
    'maerz': 3,
    'april': 4,
    'apr': 4,
    'may': 5,
    'mai': 5,
    'june': 6,
    'jun': 6,
    'juni': 6,
    'july': 7,
    'jul': 7,
    'juli': 7,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sep': 9,
    'sept': 9,
    'october': 10,
    'oct': 10,
    'oktober': 10,
    'okt': 10,
    'november': 11,
    'nov': 11,
    'december': 12,
    'dec': 12,
    'dezember': 12,
    'dez': 12,
  };

  static DateTime? _date(int year, int month, int day) {
    if (year < 1900 || year > 2100) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static Iterable<DateTime> _dates(String line) sync* {
    for (final m
        in RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').allMatches(line)) {
      final date = _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      if (date != null) yield date;
    }
    for (final m in RegExp(r'\b(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})\b')
        .allMatches(line)) {
      final date = _date(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
      if (date != null) yield date;
    }
    for (final m in RegExp(r'\b(\d{1,2})\.?\s+([a-zäöü]+)\.?\s+(\d{4})\b',
            caseSensitive: false)
        .allMatches(line)) {
      final month = _months[m[2]!.toLowerCase()];
      final date = month == null
          ? null
          : _date(int.parse(m[3]!), month, int.parse(m[1]!));
      if (date != null) yield date;
    }
    for (final m
        in RegExp(r'\b([a-z]+)\s+(\d{1,2}),?\s+(\d{4})\b', caseSensitive: false)
            .allMatches(line)) {
      final month = _months[m[1]!.toLowerCase()];
      final date = month == null
          ? null
          : _date(int.parse(m[3]!), month, int.parse(m[2]!));
      if (date != null) yield date;
    }
  }

  // Deliberately exclude customer, invoice and claim numbers: they identify
  // different records, even when they happen to equal a stored contract number.
  static final numberLabel = RegExp(
    r'\b(?:(?:vertrags?|versicherungs?(?:schein)?|vers\.?|policen?|polizzen?|vs)[ \-]*(?:nummer|nr\.?|no\.?)|(?:contract|insurance|ensurance|policy|agreement)[ \-]*(?:number|no\.?|nr\.?|#))(?=\s|:|#|[0-9]|$)',
    caseSensitive: false,
  );
  static final unrelatedNumberLabel = RegExp(
    r'\b(?:(?:kunden|rechnungs|schadens|bestell)[ \-]*(?:nummer|nr\.?)|(?:customer|invoice|claim|order)[ \-]*(?:number|no\.?|#))',
    caseSensitive: false,
  );
  static String normalizeNumber(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static List<DocumentNumberEvidence> extractNumbers(String text) {
    final lines = text.split(RegExp(r'[\r\n]+')).map((s) => s.trim()).toList();
    final found = <String, DocumentNumberEvidence>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final label in numberLabel.allMatches(line)) {
        var suffix =
            line.substring(label.end).replaceFirst(RegExp(r'^[\s:#=–-]+'), '');
        var passage = line;
        if (suffix.isEmpty && i + 1 < lines.length) {
          suffix = lines[i + 1];
          passage = '$line\n$suffix';
        }
        final tokens = suffix.split(RegExp(r'\s+'));
        final value = <String>[];
        for (var j = 0; j < tokens.length; j++) {
          final token = tokens[j].replaceFirst(RegExp(r'[,;:]$'), '');
          if (!RegExp(r'^[a-z0-9][a-z0-9./_-]*$', caseSensitive: false)
              .hasMatch(token)) {
            break;
          }
          if (!RegExp(r'\d').hasMatch(token)) {
            // A short alphabetic prefix is common; prose following a number is not.
            if (j != 0 ||
                token.length > 4 ||
                tokens.length < 2 ||
                !RegExp(r'^\d').hasMatch(tokens[1])) {
              break;
            }
          }
          value.add(token);
          if (value.join().length > 40) break;
        }
        final number = value.join(' ');
        final normalized = normalizeNumber(number);
        if (normalized.length < 4 ||
            normalized.length > 40 ||
            !RegExp(r'\d').hasMatch(number) ||
            _dates(number).isNotEmpty) {
          continue;
        }
        found.putIfAbsent(
            normalized, () => DocumentNumberEvidence(number, passage));
      }
    }
    return found.values.toList();
  }

  static final _candidateNumber = RegExp(
      r'(?<![a-z0-9])(?:[a-z]{1,5}[-/ ._]?)?\d[a-z0-9/._-]*[a-z0-9](?![a-z0-9])',
      caseSensitive: false);

  static List<DocumentNumberEvidence> headingNumbers(String passage) {
    if (unrelatedNumberLabel.hasMatch(passage) ||
        RegExp(r'\b(?:iban|bic|telefon|phone|fax)\b', caseSensitive: false)
            .hasMatch(passage)) {
      return [];
    }
    return [
      for (final m in _candidateNumber.allMatches(passage))
        if (normalizeNumber(m[0]!).length >= 6 &&
            normalizeNumber(m[0]!).length <= 24 &&
            RegExp(r'\d').allMatches(m[0]!).length >= 4 &&
            _dates(m[0]!).isEmpty &&
            !RegExp(r'^(?:for|from|den|vom|zum|year|seit|until)\s*(?:19|20)\d{2}$',
                    caseSensitive: false)
                .hasMatch(m[0]!) &&
            !RegExp(r'^[a-z]{2}\d{2}[a-z0-9]{11,30}$', caseSensitive: false)
                .hasMatch(normalizeNumber(m[0]!)))
          DocumentNumberEvidence(m[0]!, passage)
    ];
  }

  static bool _looksLikeSubject(String line) => RegExp(
          r'\b(?:[a-zäöüß]*versicherung(?:en)?|versicherungsbeitrag|vertrag|vertragsunterlagen|beitrag|beiträge|beitraege|prämie|praemie|zahlungsweise|bankverbindung|insurance|policy|contract|premium|payment|renewal|agreement|coverage)\b',
          caseSensitive: false)
      .hasMatch(line);

  static DocumentMetadataSuggestion extract(String text,
      {List<DocumentTextLine> positions = const []}) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    // OCR block order can place the salutation ahead of the subject. When
    // geometry covers the page text, restore top-to-bottom reading order.
    final positionedLines =
        positions.where((p) => lines.contains(p.text.trim())).toList()
          ..sort((a, b) {
            final y = a.top.compareTo(b.top);
            return y != 0 ? y : a.left.compareTo(b.left);
          });
    if (positionedLines.map((p) => p.text.trim()).toSet().length >=
        lines.length * .8) {
      final ordered = <String>{
        ...positionedLines.map((p) => p.text.trim()),
        ...lines
      };
      lines
        ..clear()
        ..addAll(ordered);
    }
    String? subject, subjectPassage;
    final dates = <DocumentDateEvidence>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (subject == null) {
        final match = _subject.firstMatch(line);
        if (match != null) {
          final value = match[1]!.trim().isNotEmpty
              ? match[1]!.trim()
              : (i + 1 < lines.length ? lines[i + 1] : '');
          final suggested = _shortSubject(value);
          if (suggested != null) {
            subject = suggested;
            subjectPassage = match[1]!.trim().isEmpty ? '$line\n$value' : line;
          }
        }
      }
      // Separate labelled fields on the same line before evaluating dates.
      final fields = line.split(RegExp(
          r'(?=\b(?:Rechnungsdatum|Belegdatum|Dokumentdatum|Document date|Invoice date|Issue date|Due date|Fällig|Zahlbar|Versicherungsbeginn|Geburtsdatum)\s*:)',
          caseSensitive: false));
      for (final field in fields) {
        final positioned =
            positions.where((p) => p.text.trim() == line).toList();
        final preceding = i == 0
            ? <DocumentTextLine>[]
            : positions.where((p) => p.text.trim() == lines[i - 1]).toList();
        // A label in the left column must not classify a date in the right column.
        final alignedLabel = positioned.isEmpty ||
            preceding.isEmpty ||
            positioned.any((dateLine) => preceding.any((label) =>
                (dateLine.left - label.left).abs() <= .15 &&
                dateLine.top - label.top >= -.01 &&
                dateLine.top - label.top <= .08));
        var context = field;
        if (i > 0 &&
            alignedLabel &&
            !_dateLabel.hasMatch(field) &&
            !_documentLabel.hasMatch(field) &&
            _dates(lines[i - 1]).isEmpty &&
            (_dateLabel.hasMatch(lines[i - 1]) ||
                _documentLabel.hasMatch(lines[i - 1]) ||
                _otherDate.hasMatch(lines[i - 1])) &&
            lines[i - 1].length < 70) {
          context = '${lines[i - 1]}\n$field';
        }
        if (_otherDate.hasMatch(context) ||
            numberLabel.hasMatch(context) ||
            unrelatedNumberLabel.hasMatch(context)) {
          continue;
        }
        final upperHalf = positioned.any((p) => p.top >= 0 && p.top <= .5);
        final upperRight = positioned.any(
            (p) => p.top >= 0 && p.top <= .5 && p.left >= .5 && p.left <= 1);
        final regionPriority = upperRight
            ? 300
            : upperHalf
                ? 200
                : 0;
        final cityDate =
            RegExp(r'^[A-ZÄÖÜ][a-zA-ZäöüÄÖÜß .-]+,\s*(?:den\s+)?\d')
                .hasMatch(field);
        final labelPriority = _documentLabel.hasMatch(context)
            ? 100
            : _dateLabel.hasMatch(context)
                ? 70
                : cityDate
                    ? 50
                    : 20;
        final priority = regionPriority + labelPriority;
        for (final date in _dates(field)) {
          dates.add(DocumentDateEvidence(date, context.trim(), priority));
        }
      }
    }
    if (subject == null) {
      for (var i = 0; i < lines.length && i < 40; i++) {
        final line = lines[i];
        // A heading is expected before the letter's salutation. Avoid extracting
        // a generic mention in body paragraphs or the sender/address block.
        if (_salutation.hasMatch(line)) break;
        if (line.length > 200 ||
            !_heading.hasMatch(line) ||
            line.split(' ').length > 18 ||
            RegExp(r'\b(?:gmbh|ltd|inc|straße|strasse|telefon|fax)\b|https?://|@',
                    caseSensitive: false)
                .hasMatch(line)) {
          continue;
        }
        var passage = line;
        // A short heading can wrap onto a second line (e.g. Beitragsrechnung / für 2027).
        if (i + 1 < lines.length &&
            line.length < 55 &&
            RegExp(r'^(?:für|fuer|zum|zur|for|für das Jahr|for the year)\b',
                    caseSensitive: false)
                .hasMatch(lines[i + 1]) &&
            lines[i + 1].length < 60) {
          passage = '$line\n${lines[i + 1]}';
        }
        final suggested = _shortSubject(passage);
        if (suggested != null) {
          subject = suggested;
          subjectPassage = passage;
          break;
        }
      }
    }
    // Scans do not provide reliable bold-font metadata. Larger lines in the
    // subject area are a layout hint; embedded PDF text can additionally be bold.
    final heights = positions
        .where((p) => p.height > 0)
        .map((p) => p.height)
        .toList()
      ..sort();
    final median = heights.isEmpty ? 0.0 : heights[heights.length ~/ 2];
    final prominent = positions
        .where((p) =>
            p.top >= .12 &&
            p.top <= .65 &&
            (p.isBold || (median > 0 && p.height >= median * 1.25)))
        .map((p) => p.text.trim())
        .toSet();
    if (subject == null) {
      for (final line in lines.take(40)) {
        if (_salutation.hasMatch(line)) break;
        if (line.length < 8 ||
            line.length > 160 ||
            line.split(' ').length > 16 ||
            (!prominent.contains(line) && !_looksLikeSubject(line)) ||
            _documentLabel.hasMatch(line) ||
            _dateLabel.hasMatch(line) ||
            RegExp(r'\b(?:gmbh|ltd|inc|straße|strasse|telefon|fax|postfach|herrn?|frau|mr|mrs)\b|https?://|@',
                    caseSensitive: false)
                .hasMatch(line)) {
          continue;
        }
        final suggested = _shortSubject(line);
        if (suggested != null) {
          subject = suggested;
          subjectPassage = line;
          break;
        }
      }
    }
    final numbers = <String, DocumentNumberEvidence>{
      for (final n in extractNumbers(text)) normalizeNumber(n.number): n
    };
    if (subjectPassage != null) {
      for (final candidate in headingNumbers(subjectPassage)) {
        numbers.putIfAbsent(normalizeNumber(candidate.number), () => candidate);
      }
      // Remove an identifier from a subject-style title, keeping the source intact.
      if (_looksLikeSubject(subjectPassage)) {
        var clean = subjectPassage;
        for (final candidate in headingNumbers(subjectPassage)) {
          clean = clean.replaceAll(candidate.number, '');
        }
        subject =
            _shortSubject(clean.replaceAll(RegExp(r'[–: -]+$'), '')) ?? subject;
      }
    }
    dates.sort((a, b) => b.priority.compareTo(a.priority));
    final unique = <DateTime, DocumentDateEvidence>{};
    for (final evidence in dates) {
      unique.putIfAbsent(evidence.date, () => evidence);
    }
    final candidates = unique.values.toList();
    final best = candidates.isEmpty
        ? <DocumentDateEvidence>[]
        : candidates
            .where((e) => e.priority == candidates.first.priority)
            .toList();
    return DocumentMetadataSuggestion(
        subject: subject,
        subjectPassage: subjectPassage,
        date: best.length == 1 ? best.single.date : null,
        dates: candidates,
        numbers: numbers.values.toList());
  }
}
