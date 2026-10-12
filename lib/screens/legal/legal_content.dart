// Imprint and privacy policy copy. Legal text is kept here rather than in the
// ARB catalogs: it is long-form, versioned as a whole, and the German imprint
// is the legally binding version (English is a courtesy translation).

class LegalSection {
  const LegalSection({this.heading, required this.paragraphs});

  final String? heading;
  final List<String> paragraphs;
}

const _publisher = 'Harry Neufeld\nWegscheid 25\n53347 Alfter';
const _phone = '0228 94 77 33 69';
const _email = 'office@harry-neufeld.de';
const _vatId = 'DE341000017';

const imprintDe = <LegalSection>[
  LegalSection(heading: 'Angaben gemäß §\u00a05 DDG', paragraphs: [
    'qontract ist ein Produkt von Line of Business, einer Marke von:',
    _publisher,
  ]),
  LegalSection(heading: 'Kontakt', paragraphs: [
    'Telefon: $_phone\nE-Mail: $_email',
  ]),
  LegalSection(heading: 'Umsatzsteuer-ID', paragraphs: [
    'Umsatzsteuer-Identifikationsnummer gemäß §\u00a027\u00a0a Umsatzsteuergesetz:\n$_vatId',
  ]),
];

const imprintEn = <LegalSection>[
  LegalSection(heading: 'Information pursuant to §\u00a05 DDG', paragraphs: [
    'qontract is a product of Line of Business, a brand of:',
    _publisher,
  ]),
  LegalSection(heading: 'Contact', paragraphs: [
    'Phone: +49 228 94 77 33 69\nEmail: $_email',
  ]),
  LegalSection(heading: 'VAT ID', paragraphs: [
    'VAT identification number pursuant to §\u00a027\u00a0a of the German VAT Act:\n$_vatId',
  ]),
];

const privacyDe = <LegalSection>[
  LegalSection(paragraphs: [
    'Der Schutz Ihrer Daten ist mir wichtig. qontract kommt ohne Tracking, '
        'Analyse-Tools und Werbung aus.',
  ]),
  LegalSection(heading: '1. Verantwortlicher', paragraphs: [
    'Harry Neufeld, Wegscheid 25, 53347 Alfter',
    'Telefon: $_phone · E-Mail: $_email',
  ]),
  LegalSection(heading: '2. Server-Logfiles', paragraphs: [
    'Beim Aufruf der App und ihrer Schnittstelle verarbeiten die Server technisch '
        'notwendige Daten (IP-Adresse, Datum und Uhrzeit, aufgerufene Adresse, '
        'übertragene Datenmenge, Browser-Kennung), um die App auszuliefern und '
        'die Sicherheit des Betriebs zu gewährleisten.',
    'Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO. Logdaten werden nach kurzer '
        'Zeit gelöscht, sofern sie nicht zur Aufklärung eines Sicherheitsvorfalls '
        'benötigt werden.',
  ]),
  LegalSection(heading: '3. Benutzerkonto und Inhalte', paragraphs: [
    'Für Ihr Benutzerkonto verarbeite ich Name, E-Mail-Adresse und Zugangsdaten '
        'sowie die Zugehörigkeit zu Arbeitsbereichen. Inhalte, die Sie in qontract '
        'erfassen – etwa Verträge, Vertragspartner, Adressen, Rechnungen und '
        'hochgeladene Dokumente – werden ausschließlich gespeichert, um Ihnen und '
        'den Mitgliedern Ihres Arbeitsbereichs die Vertragsverwaltung '
        'bereitzustellen.',
    'Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO. Die Daten werden gelöscht, '
        'sobald Sie sie entfernen oder Ihr Konto aufgelöst wird, sofern keine '
        'gesetzlichen Aufbewahrungspflichten entgegenstehen.',
  ]),
  LegalSection(heading: '4. E-Mails', paragraphs: [
    'Zum Einrichten und Zurücksetzen von Passwörtern versendet qontract E-Mails '
        'an die angegebene Adresse. Rechtsgrundlage ist Art. 6 Abs. 1 '
        'lit. b DSGVO.',
  ]),
  LegalSection(heading: '5. Speicherung auf Ihrem Gerät', paragraphs: [
    'Es werden keine Tracking-Cookies eingesetzt. Damit Sie angemeldet bleiben, '
        'speichert die App ein Sitzungs-Token und Ihre Profildaten lokal auf Ihrem '
        'Gerät (im Browser im lokalen Speicher), außerdem Ihre gewählte Sprache '
        'und Darstellung. Beim Abmelden wird die Sitzung entfernt '
        '(§\u00a025 Abs. 2 Nr. 2 TDDDG).',
  ]),
  LegalSection(
      heading: '6. Programmbestandteile und Schriftarten',
      paragraphs: [
        'Die Web-Version lädt technische Programmbestandteile und Schriftarten von '
            'Servern der Google Ireland Limited (gstatic.com). Dabei wird Ihre '
            'IP-Adresse an Google übermittelt. Rechtsgrundlage ist Art. 6 Abs. 1 '
            'lit. f DSGVO; das berechtigte Interesse liegt in einer schnellen und '
            'zuverlässigen Darstellung der App. Links zu externen Angeboten werden erst '
            'beim Anklicken aufgerufen; dort gelten die Datenschutzhinweise des '
            'jeweiligen Anbieters.',
      ]),
  LegalSection(heading: '7. Ihre Rechte', paragraphs: [
    'Sie haben das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der '
        'Verarbeitung, Datenübertragbarkeit sowie Widerspruch gegen Verarbeitungen '
        'auf Grundlage berechtigter Interessen (Art. 15–21 DSGVO). Wenden Sie sich '
        'dazu einfach an die oben genannten Kontaktdaten.',
    'Zudem können Sie sich bei einer Datenschutz-Aufsichtsbehörde beschweren, '
        'z. B. bei der Landesbeauftragten für Datenschutz und Informationsfreiheit '
        'Nordrhein-Westfalen.',
  ]),
  LegalSection(paragraphs: ['Stand: Oktober 2026']),
];

const privacyEn = <LegalSection>[
  LegalSection(paragraphs: [
    'Protecting your data matters to me. qontract uses no tracking, analytics '
        'or advertising.',
  ]),
  LegalSection(heading: '1. Controller', paragraphs: [
    'Harry Neufeld, Wegscheid 25, 53347 Alfter, Germany',
    'Phone: +49 228 94 77 33 69 · Email: $_email',
  ]),
  LegalSection(heading: '2. Server log files', paragraphs: [
    'When you use the app and its API, the servers process technically necessary '
        'data (IP address, date and time, requested address, amount of data '
        'transferred, browser identifier) to deliver the app and keep its '
        'operation secure.',
    'The legal basis is Art. 6(1)(f) GDPR. Log data is deleted after a short '
        'time unless it is needed to investigate a security incident.',
  ]),
  LegalSection(heading: '3. User account and content', paragraphs: [
    'For your user account I process your name, email address and sign-in data, '
        'as well as your workspace memberships. Content you enter in qontract – '
        'such as contracts, contractors, addresses, invoices and uploaded '
        'documents – is stored solely to provide contract management to you and '
        'the members of your workspace.',
    'The legal basis is Art. 6(1)(b) GDPR. The data is deleted when you remove '
        'it or your account is closed, unless statutory retention obligations '
        'apply.',
  ]),
  LegalSection(heading: '4. Emails', paragraphs: [
    'qontract sends emails to the address you provide to set up and reset '
        'passwords. The legal basis is Art. 6(1)(b) GDPR.',
  ]),
  LegalSection(heading: '5. Storage on your device', paragraphs: [
    'No tracking cookies are used. To keep you signed in, the app stores a '
        'session token and your profile data locally on your device (in the '
        "browser's local storage), as well as your chosen language and "
        'appearance. Signing out removes the session (§\u00a025(2) no. 2 TDDDG).',
  ]),
  LegalSection(heading: '6. Program components and fonts', paragraphs: [
    'The web version loads technical program components and fonts from servers '
        'of Google Ireland Limited (gstatic.com), which transmits your IP address '
        'to Google. The legal basis is Art. 6(1)(f) GDPR; the legitimate interest '
        'is fast and reliable rendering of the app. Links to external services '
        "are only opened when you click them; the provider's privacy policy "
        'applies there.',
  ]),
  LegalSection(heading: '7. Your rights', paragraphs: [
    'You have the right to access, rectification, erasure, restriction of '
        'processing, data portability and to object to processing based on '
        'legitimate interests (Art. 15–21 GDPR). Simply use the contact details '
        'above.',
    'You may also lodge a complaint with a data protection supervisory '
        'authority, e.g. the State Commissioner for Data Protection and Freedom '
        'of Information of North Rhine-Westphalia.',
  ]),
  LegalSection(paragraphs: [
    'As of October 2026. In case of doubt, the German version applies.',
  ]),
];
