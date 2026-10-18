import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/services/document_text_line.dart';
import 'package:qontract_app/services/document_metadata_extractor.dart';

void main() {
  test('upper-half dates outrank labelled dates in the lower half', () {
    final result = DocumentMetadataExtractor
        .extract('18.10.2026\nDocument date: 12.10.2026', positions: [
      const DocumentTextLine('18.10.2026', top: .25, left: .1),
      const DocumentTextLine('Document date: 12.10.2026', top: .75, left: .7),
    ]);
    expect(result.date, DateTime(2026, 10, 18));
    expect(result.dates, hasLength(2));
  });
  test('top-half right-side date outranks an explicit date at the left', () {
    final result = DocumentMetadataExtractor
        .extract('Document date: 12.10.2026\nBerlin, 18.10.2026', positions: [
      const DocumentTextLine('Document date: 12.10.2026', top: .25, left: .1),
      const DocumentTextLine('Berlin, 18.10.2026', top: .48, left: .65),
    ]);
    expect(result.date, DateTime(2026, 10, 18));
  });
  test('unrelated labels in another column do not suppress the right-hand date',
      () {
    final result =
        DocumentMetadataExtractor.extract('Due date:\n18.10.2026', positions: [
      const DocumentTextLine('Due date:', top: .2, left: .1),
      const DocumentTextLine('18.10.2026', top: .22, left: .7),
    ]);
    expect(result.date, DateTime(2026, 10, 18));
    expect(
        DocumentMetadataExtractor.extract('Due date:\n18.10.2026', positions: [
          const DocumentTextLine('Due date:', top: .2, left: .7),
          const DocumentTextLine('18.10.2026', top: .23, left: .7),
        ]).date,
        isNull);
  });
  test(
      'equal upper-right candidates remain unselected and labelled deadlines stay excluded',
      () {
    final result = DocumentMetadataExtractor.extract(
        '18.10.2026\n19.10.2026\nDue date: 31.10.2026',
        positions: [
          const DocumentTextLine('18.10.2026', top: .2, left: .7),
          const DocumentTextLine('19.10.2026', top: .3, left: .7),
          const DocumentTextLine('Due date: 31.10.2026', top: .1, left: .7),
        ]);
    expect(result.date, isNull);
    expect(result.dates, hasLength(2));
  });
  test('OCR spaces between numeric date components are accepted', () {
    expect(DocumentMetadataExtractor.extract('Datum: 18. 10. 2026').date,
        DateTime(2026, 10, 18));
  });

  test('page geometry restores a subject ahead of an out-of-order salutation',
      () {
    final result = DocumentMetadataExtractor.extract(
        'Dear customer\nYour home insurance AB-12345678\nOrdinary text',
        positions: [
          const DocumentTextLine('Dear customer',
              top: .5, left: .1, height: .02),
          const DocumentTextLine('Your home insurance AB-12345678',
              top: .3, left: .1, height: .04),
          const DocumentTextLine('Ordinary text',
              top: .6, left: .1, height: .02),
        ]);
    expect(result.subject, 'Your home insurance');
    expect(result.contractNumber, 'AB-12345678');
  });

  test(
      'an unlabelled insurance subject supplies a number and a cleaner short title',
      () {
    final result = DocumentMetadataExtractor.extract(
        'Example GmbH\nIhre Hausratversicherung AB-12345678\nSehr geehrte Kundin');
    expect(result.subject, 'Ihre Hausratversicherung');
    expect(result.contractNumber, 'AB-12345678');
    expect(
        result.numbers.single.passage, 'Ihre Hausratversicherung AB-12345678');
  });
  test('prominent subject area can provide a title without a known keyword',
      () {
    final result = DocumentMetadataExtractor.extract(
        'Example GmbH\nÄnderung der Zahlungsart XY-99887766\nSehr geehrte Kundin',
        positions: [
          const DocumentTextLine('Example GmbH',
              top: .03, left: .1, height: .02),
          const DocumentTextLine('Änderung der Zahlungsart XY-99887766',
              top: .3, left: .1, height: .04),
          const DocumentTextLine('Sehr geehrte Kundin',
              top: .45, left: .1, height: .02),
          const DocumentTextLine('Ordinary body text',
              top: .5, left: .1, height: .02),
        ]);
    expect(result.subject, 'Änderung der Zahlungsart XY-99887766');
    expect(result.contractNumber, 'XY-99887766');
  });
  test('bold embedded PDF subjects are usable even at normal text height', () {
    final result = DocumentMetadataExtractor.extract(
        'Wechsel der Zahlungsart\nDear customer',
        positions: [
          const DocumentTextLine('Wechsel der Zahlungsart',
              top: .3, left: .1, height: .02, isBold: true),
        ]);
    expect(result.subject, 'Wechsel der Zahlungsart');
  });
  test('heading numbers exclude years, dates, bank details and unrelated IDs',
      () {
    for (final heading in [
      'Your annual statement for 2026',
      'Policy renewal 18.10.2026',
      'Invoice number AB-12345678',
      'IBAN DE89370400440532013000'
    ]) {
      expect(DocumentMetadataExtractor.headingNumbers(heading), isEmpty,
          reason: heading);
    }
  });

  test(
      'prefixed and wrapped headings provide a short title without a subject label',
      () {
    final result = DocumentMetadataExtractor.extract(
        'Northwind GmbH\nIhre neue Beitragsrechnung\nfür 2027\nSehr geehrte Kundin');
    expect(result.subject, 'Ihre neue Beitragsrechnung für 2027');
    expect(result.subjectPassage, 'Ihre neue Beitragsrechnung\nfür 2027');
    expect(
        DocumentMetadataExtractor.extract(
                'Your annual statement for 2026\nDear customer')
            .subject,
        'Your annual statement for 2026');
  });
  test(
      'subject labels without a colon and subjects containing dates are supported',
      () {
    expect(
        DocumentMetadataExtractor.extract(
                'Betreff Ihre Rechnung vom 18.10.2026')
            .subject,
        'Ihre Rechnung vom 18.10.2026');
    expect(
        DocumentMetadataExtractor.extract('Subject\nYour annual statement')
            .subject,
        'Your annual statement');
  });
  test('long subjects are shortened while the original evidence stays complete',
      () {
    const subject =
        'Your annual insurance statement with details about the adjusted premiums and changes to your payment schedule for the coming year';
    final result = DocumentMetadataExtractor.extract('Subject: $subject');
    expect(result.subject!.length, lessThanOrEqualTo(73));
    expect(result.subject, endsWith('…'));
    expect(result.subjectPassage, 'Subject: $subject');
  });
  test('body paragraphs and addresses alone never become a subject', () {
    expect(
        DocumentMetadataExtractor.extract(
                'Northwind GmbH\n12345 Berlin\nDear customer\nPlease find the invoice enclosed.')
            .subject,
        isNull);
    expect(DocumentMetadataExtractor.extract('Subject: 18.10.2026').subject,
        isNull);
  });

  test('common German and English contract labels retain actual evidence', () {
    for (final label in [
      'Vertragsnummer',
      'Vertrags-Nr.',
      'Versicherungsnummer',
      'Versicherung Nr.',
      'Vers.-Nr.',
      'Versicherungsschein-Nr.',
      'Policennummer',
      'Police Nr.',
      'VS-Nr.',
      'Contract number',
      'Contract no.',
      'Insurance number',
      'Ensurance number',
      'Policy number',
      'Policy #',
      'Agreement no.'
    ]) {
      final result = DocumentMetadataExtractor.extract('$label: AB-123456');
      expect(result.contractNumber, 'AB-123456', reason: label);
      expect(result.numbers.single.passage, '$label: AB-123456');
    }
  });
  test(
      'wrapped labels, spaced identifiers and multiple candidates remain reviewable',
      () {
    final result = DocumentMetadataExtractor.extract(
        'Versicherungsnummer:\nAB 123 456\nPolicy number: XY-998877');
    expect(result.contractNumber, isNull);
    expect(result.numbers.map((n) => n.number), ['AB 123 456', 'XY-998877']);
    expect(result.numbers.first.passage, 'Versicherungsnummer:\nAB 123 456');
  });
  test('numbers exclude prose, customer IDs, invoice IDs, dates and short IDs',
      () {
    for (final source in [
      'Kundennummer: AB-123456',
      'Invoice number: AB-123456',
      'Policy number: 18.10.2026',
      'Contract number: 42',
      'Policy number: see attached document'
    ]) {
      expect(DocumentMetadataExtractor.extract(source).numbers, isEmpty,
          reason: source);
    }
    expect(
        DocumentMetadataExtractor.extract(
                'Contract number: AB-123456 please quote this')
            .contractNumber,
        'AB-123456');
  });
  test('upper-right position takes priority over dates outside that region',
      () {
    const positions = [DocumentTextLine('18.10.2026', top: .2, left: .7)];
    expect(
        DocumentMetadataExtractor.extract('18.10.2026\n12.10.2026',
                positions: positions)
            .date,
        DateTime(2026, 10, 18));
    expect(
        DocumentMetadataExtractor.extract(
                '18.10.2026\nDocument date: 12.10.2026',
                positions: positions)
            .date,
        DateTime(2026, 10, 18));
    expect(
        DocumentMetadataExtractor.extract('Due date: 18.10.2026', positions: [
          const DocumentTextLine('Due date: 18.10.2026', top: .2, left: .7)
        ]).date,
        isNull);
  });
  test('city date beats an unlabeled date and same-line due dates are excluded',
      () {
    expect(
        DocumentMetadataExtractor.extract('Berlin, den 18.10.2026\n12.10.2026')
            .date,
        DateTime(2026, 10, 18));
    final result = DocumentMetadataExtractor.extract(
        'Invoice date: 18.10.2026 Due date: 31.10.2026');
    expect(result.date, DateTime(2026, 10, 18));
    expect(result.dates, hasLength(1));
  });

  test('German subject and invoice date win over due and coverage dates', () {
    final result =
        DocumentMetadataExtractor.extract('''Versicherungsbeginn: 01.01.2020
Fällig am 31.10.2026
Rechnungsdatum: 15.10.2026
Betreff: Ihre Beitragsrechnung 2027''');
    expect(result.subject, 'Ihre Beitragsrechnung 2027');
    expect(result.date, DateTime(2026, 10, 15));
    expect(result.dates, hasLength(1));
    expect(result.dates.single.passage, 'Rechnungsdatum: 15.10.2026');
  });
  test('English named months and subject on following line are recognized', () {
    final result = DocumentMetadataExtractor.extract('''Subject:
Annual renewal
Issue date: October 18, 2026
Due date: November 2, 2026''');
    expect(result.subject, 'Annual renewal');
    expect(result.subjectPassage, 'Subject:\nAnnual renewal');
    expect(result.date, DateTime(2026, 10, 18));
  });
  test('label on preceding line is preserved as evidence', () {
    final result =
        DocumentMetadataExtractor.extract('Rechnungsdatum\n18. Oktober 2026');
    expect(result.date, DateTime(2026, 10, 18));
    expect(result.dates.single.passage, 'Rechnungsdatum\n18. Oktober 2026');
  });
  test(
      'an unlabelled ISO date is accepted, while repeated dates are deduplicated',
      () {
    final result =
        DocumentMetadataExtractor.extract('2026-10-18\nDatum: 18.10.2026');
    expect(result.date, DateTime(2026, 10, 18));
    expect(result.dates, hasLength(1));
    expect(result.dates.single.priority, 70);
  });
  test('equally likely dates remain unselected for user review', () {
    final result = DocumentMetadataExtractor.extract('01.10.2026\n18.10.2026');
    expect(result.date, isNull);
    expect(result.dates, hasLength(2));
  });
  test('invalid dates and ambiguous slash dates are never guessed', () {
    for (final text in [
      'Datum: 31.02.2026',
      'Date: 01/02/2026',
      '2026-13-01'
    ]) {
      expect(DocumentMetadataExtractor.extract(text).dates, isEmpty);
    }
  });
  test('headings suggest a title but an explicit subject has priority', () {
    expect(DocumentMetadataExtractor.extract('Invoice 2026-42\nHello').subject,
        'Invoice 2026-42');
    expect(
        DocumentMetadataExtractor.extract(
                'Invoice\nSubject: Your updated premium')
            .subject,
        'Your updated premium');
    expect(
        DocumentMetadataExtractor.extract('Northwind GmbH\nDear customer')
            .subject,
        isNull);
  });
  test('a due date alone never fills the document date', () {
    expect(
        DocumentMetadataExtractor.extract('Fälligkeitsdatum:\n31.10.2026').date,
        isNull);
    expect(DocumentMetadataExtractor.extract('Due date: October 31, 2026').date,
        isNull);
  });
}
