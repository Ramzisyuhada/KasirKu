/// 3500 → "Rp3.500"
String rupiah(int value) {
  final digits = value.abs().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );
  return '${value < 0 ? '-' : ''}Rp$digits';
}

/// "Indomie Goreng" → "IG"
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length < 2 ? word.length : 2).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// "3.500" atau "3500" → 3500
int parseRupiah(String text) => int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _two(int n) => n.toString().padLeft(2, '0');

/// 24 Nov 2026
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// 09.41
String formatTime(DateTime d) => '${_two(d.hour)}.${_two(d.minute)}';

/// 24 Nov 2026, 09.41
String formatDateTime(DateTime d) => '${formatDate(d)}, ${formatTime(d)}';

String paymentLabel(String method) => switch (method) {
      'cash' => 'Tunai',
      'qris' => 'QRIS',
      'transfer' => 'Transfer',
      _ => method,
    };