/// Округление результата до разумного числа знаков после запятой.
String formatNumber(double value) {
  if (value.isNaN || value.isInfinite) {
    return value.toString();
  }
  final rounded = double.parse(value.toStringAsFixed(10));
  if (rounded == rounded.roundToDouble()) {
    return rounded.round().toString();
  }
  var s = rounded.toStringAsFixed(8);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.endsWith('.') ? s.substring(0, s.length - 1) : s.substring(0, s.length - 1);
  }
  return s;
}
