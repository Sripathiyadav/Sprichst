/// "1 card", "2 cards": [word] with an "s" unless [n] is exactly one.
String countOf(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
