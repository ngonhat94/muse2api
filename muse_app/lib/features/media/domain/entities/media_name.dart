bool isDeletableMediaName(String name) =>
    name.isNotEmpty &&
    !name.contains('/') &&
    !name.contains('\\') &&
    !name.contains('..') &&
    !name.contains('%') &&
    !name.contains(':') &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(name);
