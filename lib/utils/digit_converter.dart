class DigitConverter {
  static String cleanAndConvert(String input) {
    String clean = input.replaceAll(RegExp(r'[^\d٠-٩]'), '');
    
    var hindiDigits = {'٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9'};
    
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      String char = clean[i];
      if (hindiDigits.containsKey(char)) {
        buffer.write(hindiDigits[char]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}