import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

//프로젝트별 GOOGLE 시트 번역 문서 ID
//문서는 "링크를 가진사람은 모두 엑세스"될 수있도록 "공유" 돼 있어야 한다.

//dart bin/main.dart --doc '1VsYZH_y7bPZr8gE7rg-9PHnrOCKVKwBO7JjBpdOiEjw' --path ~/Sync/Works/godutch/lib/generated/intl --file intl.g.dart
//dart bin/main.dart --doc '1VsYZH_y7bPZr8gE7rg-9PHnrOCKVKwBO7JjBpdOiEjw' --path ~/Sync/Works/godutch/lib/home/intl --file messages.dart
Future<void> main(List<String> arguments) async {
  exitCode = 0; // presume success
  var parser = ArgParser();
  parser.addOption('doc', abbr: 'd'); //GOOGLE sheet translation doc ID
  parser.addOption('path', abbr: 'p'); //destination path
  parser.addOption('file', abbr: 'f'); //destination file

  var args = parser.parse(arguments);
  updateLocalizationFile(args);
}

Future updateLocalizationFile(ArgResults args) async {
//번역 생성할 프로젝트 폴더명
//프로젝트  .g.dart 파일 위치
  String updateProjectLocalPath = args['path'];
  String thisLocalPath = '.'; //번역프로그램 lib 위치

  String? documentId = args['doc'];
  //the sheetid of your google sheet
  String sheetId = "0";

  String _phraseKey = '';
  List<LocalizationModel> _words = [];
  String _content = """import 'package:get/get.dart';

class Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    """;

  try {
    final url =
        'https://docs.google.com/spreadsheets/d/$documentId/export?format=csv&id=$documentId&gid=$sheetId';

    stdout.writeln('');
    stdout.writeln('---------------------------------------');
    stdout.writeln('Downloading Google sheet from url("$url") ...');
    stdout.writeln('---------------------------------------');

    //--FROM GOOGLE SHEET------------------------------------------
    var response = await http
        .get(Uri.parse(url), headers: {'accept': 'text/csv;charset=UTF-8'});

    final bytes = response.bodyBytes.toList();
    final csv = Stream<List<int>>.fromIterable([bytes]);

    final fields = await csv
        .transform(utf8.decoder)
        .transform(CsvToListConverter(
          shouldParseNumbers: false,
        ))
        .toList();
    print('${fields.length} words loaded...');

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
          if (_phraseKey.isNotEmpty) {
            _words.forEach((element) {
              if (element.language == key) {
                element.phrases
                    .add(PhraseModel(key: _phraseKey, phrase: value));
                _languageAdded = true;
              }
            });

            if (_languageAdded == false) {
              _words.add(LocalizationModel(
                  language: key,
                  phrases: [PhraseModel(key: _phraseKey, phrase: value)]));
            }
          }
        }
      });
    }

    _words.forEach((_word) {
      String _lang = _word.language;
      String _currLang = "'$_lang': {\n";
      _content = _content + _currLang;
      _word.phrases.forEach((_phrase) {
        String _key = _phrase.key;
        String _phrasePhrase = _phrase.phrase.replaceAll(r"'", "\\'");
        String _currentPhraseTextCode = "\t\t'$_key': '$_phrasePhrase',\n";
        _content = _content + _currentPhraseTextCode;
      });
      String _currentLanguageCodeEnding = "},\n";
      _content = _content + _currentLanguageCodeEnding;
    });
    String _fileEnding = """
        };
      }
      """;
    _content = _content + _fileEnding;

    stdout.writeln('');
    stdout.writeln('---------------------------------------');
    stdout.writeln('Saving ${args["file"]}');
    stdout.writeln('---------------------------------------');
    final thisFile = File('$thisLocalPath/${args["file"]}');
    final projectFile = File('$updateProjectLocalPath/${args["file"]}');
    thisFile.writeAsStringSync(_content);
    stdout.writeln('Saving ${args["file"]} to ${thisFile.absolute}');
    projectFile.writeAsStringSync(_content);
    stdout.writeln('Saving ${args["file"]} to ${projectFile.absolute}');
    stdout.writeln('Done...');
  } catch (e) {
    //output error
    stderr.writeln(_content);
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
