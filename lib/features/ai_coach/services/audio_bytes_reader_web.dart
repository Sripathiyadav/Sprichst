import 'package:http/http.dart' as http;

Future<List<int>> readAudioBytes(String path) async {
  final response = await http.get(Uri.parse(path));

  if (response.statusCode != 200) {
    throw Exception(
      'Could not read browser audio blob: '
      '${response.statusCode}',
    );
  }

  return response.bodyBytes;
}
