import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:primea/modal/match.dart';
import 'package:primea/model/match/match_model.dart';
import 'package:primea/model/match/match_result_option.dart';
import 'package:primea/model/match/player_rank.dart';
import 'package:primea/model/match/player_turn.dart';
import 'package:primea/tracker/paragon.dart';
import 'package:primea/tracker/match.dart';

enum CsvColumn {
  paragon,
  opponentParagon,
  result,
  playerOne,
  opponentUsername,
  opponentRank,
  mmrDelta,
  primeEstimate,
  timestamp,
}

class Import extends StatefulWidget {
  const Import({super.key});

  @override
  State<StatefulWidget> createState() => _ImportState();
}

class _ImportState extends State<Import> {
  List<MatchModel> matches = List.empty(growable: true);
  late List<MatchModel> sampleMatches;
  bool? fileSelected;

  @override
  initState() {
    sampleMatches = sampleRows();
    super.initState();
  }

  List<MatchModel> parseCsv(Uint8List data) {
    final List<MatchModel> matches = List.empty(growable: true);
    final content = utf8.decode(data.toList());

    final lines = content.split('\n');
    final columns = lines.first.trim().split(',');
    final columnTypes = columns.toSet().map(
          (column) => CsvColumn.values.byName(column),
        );

    if (columns.length != columnTypes.length) {
      throw Exception(
        'Import error: there is a duplicated column in the CSV file. Only include ${CsvColumn.values}',
      );
    }

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      final values = line.trim().split(',');
      if (values.length != columns.length) {
        throw Exception(
          'Import error: incorrect number of columns in row $i ($line)',
        );
      }

      Paragon paragon = Paragon.unknown;
      Paragon opponentParagon = Paragon.unknown;
      MatchResultOption result = MatchResultOption.draw;
      PlayerTurn turn = PlayerTurn.going1st;
      DateTime matchTime = DateTime.now();
      String? opponentUsername;
      Rank? opponentRank;
      int? mmrDelta;
      double? primeEarned;

      for (var i = 0; i < columnTypes.length; i++) {
        if (values[i].isEmpty) {
          continue;
        }
        final CsvColumn column = columnTypes.elementAt(i);
        try {
          switch (column) {
            case CsvColumn.paragon:
              paragon = Paragon.values.byName(values[i]);
              break;
            case CsvColumn.opponentParagon:
              opponentParagon = Paragon.values.byName(values[i]);
              break;
            case CsvColumn.playerOne:
              turn = bool.parse(values[i], caseSensitive: false)
                  ? PlayerTurn.going1st
                  : PlayerTurn.going2nd;
              break;
            case CsvColumn.opponentUsername:
              opponentUsername = values[i];
              break;
            case CsvColumn.opponentRank:
              opponentRank = Rank.values.byName(values[i]);
              break;
            case CsvColumn.mmrDelta:
              mmrDelta = int.parse(values[i]);
              break;
            case CsvColumn.primeEstimate:
              primeEarned = double.parse(values[i]);
              break;
            case CsvColumn.result:
              result = MatchResultOption.values.byName(values[i]);
              break;
            case CsvColumn.timestamp:
              matchTime = DateTime.parse(values[i]);
              break;
          }
        } catch (e) {
          throw Exception(
            'Error parsing row: $i, column: $column, value: ${values[i]} ($e)}',
          );
        }
      }
      matches.add(MatchModel(
        paragon: paragon,
        playerTurn: turn,
        result: result,
        matchTime: matchTime,
        opponentUsername: opponentUsername,
        opponentParagon: opponentParagon,
        opponentRank: opponentRank,
        mmrDelta: mmrDelta,
        primeEarned: primeEarned,
      ));
    }

    return matches;
  }

  void selectFile() async {
    setState(() {
      fileSelected = false;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: ['csv'],
    );

    if (result == null) {
      setState(() {
        fileSelected = null;
      });
      return;
    }

    final data = result.files.single.bytes;
    if (data == null) {
      throw Exception('Error reading file ${result.files.single.name}');
    }
    final matches = parseCsv(data);

    setState(() {
      this.matches = matches;
      fileSelected = true;
    });
  }

  List<MatchModel> sampleRows() {
    return List.generate(
      4,
      (index) {
        var result = MatchResultOption
            .values[Random().nextInt(MatchResultOption.values.length)];
        var mmrDelta = Random().nextInt(25);
        if (result == MatchResultOption.disconnect ||
            result == MatchResultOption.draw) {
          mmrDelta = 0;
        } else if (result == MatchResultOption.loss) {
          mmrDelta = -mmrDelta;
        }
        return MatchModel(
          paragon: Paragon.values[Random().nextInt(Paragon.values.length)],
          playerTurn:
              Random().nextBool() ? PlayerTurn.going1st : PlayerTurn.going2nd,
          result: result,
          opponentUsername: 'Opponent #$index',
          opponentParagon:
              Paragon.values[Random().nextInt(Paragon.values.length)],
          mmrDelta: mmrDelta,
          opponentRank: Rank.values[Random().nextInt(Rank.values.length)],
          primeEarned:
              result == MatchResultOption.win ? Random().nextDouble() : 0,
          matchTime: DateTime.now().subtract(
            Duration(
              days: Random().nextInt(720),
              minutes: Random().nextInt(1440),
              seconds: Random().nextInt(60),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (fileSelected == null) {
      child = Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "Ensure your CSV file has the following columns: ",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  WidgetSpan(
                    child: SelectableText(
                      "[${CsvColumn.values.map((column) => column.name).join(', ')}]",
                      style: const TextStyle(
                        fontFamily: "Argon",
                        fontVariations: [FontVariation('wght', 700)],
                      ),
                    ),
                  ),
                  const TextSpan(
                    text: "\n\n",
                  ),
                  TextSpan(
                    text: "Valid Paragon values: ",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  WidgetSpan(
                    child: SelectableText(
                      "[${Paragon.values.map((paragon) => paragon.name).join(', ')}]",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: "Argon",
                        fontVariations: [const FontVariation('wght', 700)],
                      ),
                    ),
                  ),
                  const TextSpan(
                    text: "\n\n",
                  ),
                  TextSpan(
                    text: "Valid Result values: ",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  WidgetSpan(
                    child: SelectableText(
                      "[${MatchResultOption.values.map((result) => result.name).join(', ')}]",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: "Argon",
                        fontVariations: [const FontVariation('wght', 700)],
                      ),
                    ),
                  ),
                  const TextSpan(
                    text: "\n\n",
                  ),
                  TextSpan(
                    text: "Valid Rank values: ",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  WidgetSpan(
                    child: SelectableText(
                      "[${Rank.values.reversed.map((rank) => rank.name).join(', ')}]",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontVariations: [const FontVariation('wght', 700)],
                      ),
                    ),
                  ),
                  const TextSpan(
                    text: "\n\n",
                  ),
                  TextSpan(
                    text:
                        "Here is an example table.\nThe only columns required are ",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  TextSpan(
                    text:
                        "${CsvColumn.paragon.name}, ${CsvColumn.opponentParagon.name}, ${CsvColumn.result.name}, ${CsvColumn.playerOne.name}",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFamily: "Argon",
                      fontVariations: [const FontVariation('wght', 700)],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const FixedColumnWidth(175),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      children: CsvColumn.values
                          .map(
                            (column) => TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                                child: Text(
                                  column.name,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                    fontFamily: "Argon",
                                    fontVariations: [
                                      const FontVariation('wght', 700)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ...sampleMatches.map(
                      (row) => TableRow(
                        children: [
                          TableCell(
                            child: Text(
                              row.paragon.name,
                            ),
                          ),
                          TableCell(
                            child: Text(
                              row.opponentParagon.name,
                            ),
                          ),
                          TableCell(
                            child: Text(
                              row.result.name,
                            ),
                          ),
                          TableCell(
                            child: Text(
                              row.playerTurn.value ? 'true' : 'false',
                            ),
                          ),
                          TableCell(
                            child: Text(row.opponentUsername ?? ""),
                          ),
                          TableCell(
                            child: Text(row.opponentRank?.name ?? ""),
                          ),
                          TableCell(
                            child: Text(row.mmrDelta?.toString() ?? ""),
                          ),
                          TableCell(
                            child: Text(
                                row.primeEarned?.toStringAsPrecision(3) ?? ""),
                          ),
                          TableCell(
                            child: Text(row.matchTime
                                .toUtc()
                                .toIso8601String()
                                .split(".")[0]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 16),
              child: Divider(
                thickness: 2,
                indent: 16,
                endIndent: 16,
              ),
            ),
            ElevatedButton(
              onPressed: selectFile,
              child: const Text('Select CSV File'),
            ),
          ],
        ),
      );
    } else if (fileSelected != null && !fileSelected!) {
      child = const Center(child: CircularProgressIndicator());
    } else if (matches.isEmpty) {
      child = Center(
        child: TextButton(
          onPressed: () {
            setState(() {
              fileSelected = null;
            });
          },
          child: const Text('File is empty. Try again.'),
        ),
      );
    } else {
      child = ListView.builder(
        shrinkWrap: true,
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          return Match(
            match: match,
            onEdit: (context) async {
              var updatedMatch = await showDialog<MatchModel>(
                context: context,
                builder: (context) {
                  return MatchModal(
                    match: match,
                  );
                },
              );
              if (updatedMatch != null) {
                setState(() {
                  matches[index] = updatedMatch;
                });
              }
            },
            onDelete: (context) async {
              setState(() {
                matches.removeAt(index);
              });
            },
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              child: Text(
                "Import your matches from a CSV file",
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: child,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: matches.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(matches),
                child: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
