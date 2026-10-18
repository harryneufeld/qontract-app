/// OCR coordinates normalized to the upright page, with origin at top left.
class DocumentTextLine {
  final String text;
  final double top;
  final double left;
  final double height;
  final bool isBold;
  const DocumentTextLine(this.text,
      {required this.top,
      required this.left,
      this.height = 0,
      this.isBold = false});
}
