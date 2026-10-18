import '../models/contract.dart';
import 'document_metadata_extractor.dart';
import '../models/contractor.dart';

class ContractMatch {
  final Contract contract;
  final int score;
  final List<String> reasons;
  final String? contractorName;
  final List<String> passages;
  const ContractMatch(this.contract, this.score, this.reasons,
      {this.contractorName, this.passages = const []});
}

/// Conservative, explainable matching. Shared provider names and IBANs are
/// useful hints but cannot identify a particular contract on their own.
class DocumentContractMatcher {
  /// Without a label, short stored numbers turn up inside dates, postcodes
  /// and amounts (e.g. "2026" in "14.10.2026"), so they need more characters.
  static const _unlabelledMinimum = 6;

  /// Relative evidence points, not a calibrated OCR confidence percentage.
  static ContractMatch? bestDefault(List<ContractMatch> matches) {
    if (matches.isEmpty ||
        (matches.length > 1 && matches[0].score == matches[1].score)) {
      return null;
    }
    return matches.first;
  }

  static String _words(String value) => value
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static bool _phrase(String text, String? value, {int minimum = 4}) {
    final phrase = _words(value ?? '');
    return phrase.length >= minimum && ' $text '.contains(' $phrase ');
  }

  static bool _identifier(String text, String? value, {int minimum = 4}) {
    final parts =
        _words(value ?? '').split(' ').where((p) => p.isNotEmpty).toList();
    final compact = parts.join();
    if (compact.length < minimum) return false;
    // Separators may be added by OCR, but never match inside a longer number.
    final pattern = compact.split('').map(RegExp.escape).join(r'[\s./_-]*');
    return RegExp('(^|[^a-z0-9])$pattern(\$|[^a-z0-9])', caseSensitive: false)
        .hasMatch(text.toLowerCase());
  }

  static String? _passage(String text, bool Function(String) matches) {
    final lines = text.split(RegExp(r'[\r\n]+'));
    // Prefer the shortest actual source passage; identifiers can wrap in OCR.
    for (var length = 1; length <= 3; length++) {
      for (var i = 0; i + length <= lines.length; i++) {
        final passage = lines.sublist(i, i + length).join('\n').trim();
        if (matches(passage)) return passage;
      }
    }
    return null;
  }

  static List<DocumentNumberEvidence> knownNumberEvidence(
          String text, List<Contract> contracts) =>
      [
        for (final match in rank(text, contracts))
          if (match.reasons.contains('Contract number') &&
              match.passages.isNotEmpty)
            DocumentNumberEvidence(
                match.contract.contractNumber!, match.passages.first)
      ];

  static List<ContractMatch> rank(String text, List<Contract> contracts,
      {List<Contractor> contractors = const [], String? reviewedNumber}) {
    final numbers = DocumentMetadataExtractor.extractNumbers(text);
    final sourceLines = text.split(RegExp(r'[\r\n]+'));
    final numberText = [
      for (var i = 0; i < sourceLines.length; i++)
        if (!DocumentMetadataExtractor.unrelatedNumberLabel
                .hasMatch(sourceLines[i]) &&
            !(i > 0 &&
                DocumentMetadataExtractor.unrelatedNumberLabel
                    .hasMatch(sourceLines[i - 1]) &&
                !RegExp(r'\d').hasMatch(sourceLines[i - 1]) &&
                !DocumentMetadataExtractor.numberLabel
                    .hasMatch(sourceLines[i])))
          sourceLines[i]
    ].join('\n');
    final words = _words(text);
    final names = {
      for (final contractor in contractors) contractor.id: contractor.name
    };
    final matches = <ContractMatch>[];
    for (final contract in contracts) {
      var score = 0;
      final reasons = <String>[];
      final passages = <String>{};
      void evidence(bool Function(String) test) {
        final passage = _passage(text, test);
        if (passage != null) passages.add(passage);
      }

      final labelled = numbers
          .where((n) => _identifier(n.number, contract.contractNumber))
          .toList();
      final numberMatches = reviewedNumber != null
          ? DocumentMetadataExtractor.normalizeNumber(reviewedNumber)
                  .isNotEmpty &&
              DocumentMetadataExtractor.normalizeNumber(reviewedNumber) ==
                  DocumentMetadataExtractor.normalizeNumber(
                      contract.contractNumber ?? '')
          : labelled.isNotEmpty ||
              _identifier(numberText, contract.contractNumber,
                  minimum: _unlabelledMinimum);
      if (numberMatches) {
        // Tiers: a labelled or reviewed number (200) beats an unlabelled one
        // plus all other evidence (100 + 35 + 20 + 10), which in turn beats
        // any contract without a number match.
        score += reviewedNumber != null || labelled.isNotEmpty ? 200 : 100;
        reasons.add('Contract number');
        if (labelled.isNotEmpty) {
          passages.addAll(labelled.map((n) => n.passage));
        } else if (reviewedNumber == null) {
          final passage = _passage(
              numberText,
              (s) => _identifier(s, contract.contractNumber,
                  minimum: _unlabelledMinimum));
          if (passage != null) passages.add(passage);
        }
      }
      if (_phrase(words, contract.title)) {
        score += 35;
        reasons.add('Contract title');
        evidence((s) => _phrase(_words(s), contract.title));
      }
      if (_phrase(words, names[contract.contractorId])) {
        score += 20;
        reasons.add('Contractor name');
        evidence((s) => _phrase(_words(s), names[contract.contractorId]));
      }
      if (_identifier(text, contract.iban)) {
        score += 10;
        reasons.add('IBAN');
        evidence((s) => _identifier(s, contract.iban));
      }
      if (score > 0) {
        matches.add(ContractMatch(contract, score, reasons,
            contractorName: names[contract.contractorId],
            passages: passages.toList()));
      }
    }
    matches.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.contract.id.compareTo(b.contract.id);
    });
    return matches;
  }
}
