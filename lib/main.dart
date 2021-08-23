import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

void main() {
  updateLocalizationFile();
}

final projectMap = {
  "post": "1aMM-Q__xaMFOO5h1AnTUEOHxo1TKfCJMwmhHTxLBJM0",
  "rplc": "16034CeZ7qLUt72SSOpd2gkZI2N4zKy8X8KU-AnLCXzA",
};

final PROJECT_ID = 'rplc';

Future updateLocalizationFile() async {
  //the document id for your google sheet
  String? documentId = projectMap[PROJECT_ID]; //
  String updateProjectLocalPath = 'C:\\Sync\\Works\\$PROJECT_ID\\lib\\helpers';
  String thisLocalPath = 'C:\\Sync\\Works\\gs_translation\\lib';
  //the sheetid of your google sheet
  String sheetId = "0";

  String _phraseKey = '';
  List<LocalizationModel> _localizations = [];
  String _localizationFile = """import 'package:get/get.dart';

class Localization extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    """;

  try {
    //https://docs.google.com/spreadsheets/d/1aMM-Q__xaMFOO5h1AnTUEOHxo1TKfCJMwmhHTxLBJM0/edit?usp=sharing
    final url =
        'https://docs.google.com/spreadsheets/d/$documentId/export?format=csv&id=$documentId&gid=$sheetId';

    stdout.writeln('');
    stdout.writeln('---------------------------------------');
    stdout.writeln('Downloading Google sheet url "$url" ...');
    stdout.writeln('---------------------------------------');

    //--FROM GOOGLE SHEET------------------------------------------
    var response = await http
        .get(Uri.parse(url), headers: {'accept': 'text/csv;charset=UTF-8'});

    //print('Google sheet csv:\n ${response.body}');

    final bytes = response.bodyBytes.toList();
    final csv = Stream<List<int>>.fromIterable([bytes]);

    final fields = await csv
        .transform(utf8.decoder)
        .transform(CsvToListConverter(
          shouldParseNumbers: false,
        ))
        .toList();
    print(fields.length);
    //--FROM LOCALFILE------------------------------------------
    // final input =
    //     new File('C:/Users/ENOO/Downloads/post_translation - Sheet1.csv')
    //         .openRead();
    // final fields = await input
    //     .transform(utf8.decoder)
    //     .transform(new CsvToListConverter())
    //     .toList();

    final index = fields[0]
        .cast<String>()
        .map(_uniformizeKey)
        .takeWhile((x) => x.isNotEmpty)
        .toList();

    for (var r = 1; r < fields.length; r++) {
      final rowValues = fields[r];

      /// Creating a map
      final row = Map<String, String>.fromEntries(
        rowValues
            .asMap()
            .entries
            .where(
              (e) => e.key < index.length,
            )
            .map(
              (e) => MapEntry(index[e.key], e.value),
            ),
      );

      row.forEach((key, value) {
        if (key == 'key') {
          _phraseKey = value;
        } else {
          bool _languageAdded = false;
          _localizations.forEach((element) {
            if (element.language == key) {
              element.phrases.add(PhraseModel(key: _phraseKey, phrase: value));
              _languageAdded = true;
            }
          });
          if (_languageAdded == false) {
            _localizations.add(LocalizationModel(
                language: key,
                phrases: [PhraseModel(key: _phraseKey, phrase: value)]));
          }
        }
      });
    }

    _localizations.forEach((_localization) {
      String _language = _localization.language;
      String _currentLanguageTextCode = "'$_language': {\n";
      _localizationFile = _localizationFile + _currentLanguageTextCode;
      _localization.phrases.forEach((_phrase) {
        String _phraseKey = _phrase.key;
        String _phrasePhrase = _phrase.phrase.replaceAll(r"'", "\\\'");
        String _currentPhraseTextCode = "'$_phraseKey': '$_phrasePhrase',\n";
        _localizationFile = _localizationFile + _currentPhraseTextCode;
      });
      String _currentLanguageCodeEnding = "},\n";
      _localizationFile = _localizationFile + _currentLanguageCodeEnding;
    });
    String _fileEnding = """
        };
      }
      """;
    _localizationFile = _localizationFile + _fileEnding;

    stdout.writeln('');
    stdout.writeln('---------------------------------------');
    stdout.writeln('Saving localization.g.dart');
    stdout.writeln('---------------------------------------');
    final thisFile = File('$thisLocalPath\\localization.g.dart');
    final projectFile = File('$updateProjectLocalPath\\localization.g.dart');
    await thisFile.writeAsString(_localizationFile);
    stdout.writeln('Saving localization.g.dart to ${thisFile.absolute}');
    await projectFile.writeAsString(_localizationFile);
    stdout.writeln('Saving localization.g.dart to ${projectFile.absolute}');
    stdout.writeln('Done...');
  } catch (e) {
    //output error
    stderr.writeln('error: networking error');
    stderr.writeln(e.toString());
  }
}

String _uniformizeKey(String key) {
  key = key.trim().replaceAll('\n', '').toLowerCase();
  return key;
}

//Localization Model
class LocalizationModel {
  final String language;
  final List<PhraseModel> phrases;

  LocalizationModel({
    required this.language,
    required this.phrases,
  });

  factory LocalizationModel.fromMap(Map data) {
    return LocalizationModel(
      language: data['language'],
      phrases:
          (data['phrases'] as List).map((v) => PhraseModel.fromMap(v)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        "language": language,
        "phrases": List<dynamic>.from(phrases.map((x) => x.toJson())),
      };
}

class PhraseModel {
  String key;
  String phrase;

  PhraseModel({required this.key, required this.phrase});

  factory PhraseModel.fromMap(Map data) {
    return PhraseModel(
      key: data['key'],
      phrase: data['phrase'] ?? '',
    );
  }
  Map<String, dynamic> toJson() => {
        "key": key,
        "phrase": phrase,
      };
}
