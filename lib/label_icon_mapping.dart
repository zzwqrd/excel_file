class LabelIconMapping {
  static const Map<String, String> defaultIcons = {
    'Confidential': 'assets/icons/confidential.png',
    'Public': 'assets/icons/public.png',
    'Internal Use Only': 'assets/icons/internal.png',
    'Restricted': 'assets/icons/restricted.png',
  };

  static const Map<String, int> labelColors = {
    'Confidential': 0xFFFF0000, // Red
    'Public': 0xFF00FF00, // Green
    'Internal Use Only': 0xFFFFAA00, // Orange
    'Restricted': 0xFF0000FF, // Blue
  };

  static int getColorForLabel(String label) {
    return labelColors[label] ?? 0xFF888888; // Default gray
  }

  static String getIconForLabel(String label) {
    return defaultIcons[label] ?? 'assets/icons/file.png';
  }
}
