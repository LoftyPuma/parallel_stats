import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parallel_stats/model/match/inherited_match_list.dart';
import 'package:parallel_stats/model/match/match_model.dart';
import 'package:parallel_stats/model/match/match_result_option.dart';
import 'package:parallel_stats/model/match/player_rank.dart';
import 'package:parallel_stats/model/match/player_turn.dart';
import 'package:parallel_stats/snack/basic.dart';
import 'package:parallel_stats/tracker/paragon.dart';
import 'package:parallel_stats/tracker/parallel_avatar.dart';
import 'package:parallel_stats/util/string.dart';

class NewMatch extends StatefulWidget {
  final Paragon chosenParagon;

  const NewMatch({
    required this.chosenParagon,
    super.key,
  });

  @override
  State<NewMatch> createState() => _NewMatchState();
}

class _NewMatchState extends State<NewMatch> {
  PlayerTurn playerTurn = PlayerTurn.going1st;
  Paragon chosenParagon = Paragon.unknown;
  Rank? rank;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _mmrController = TextEditingController();
  final TextEditingController _primeController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _mmrController.dispose();
    _primeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchList = InheritedMatchList.of(context);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          width: 2,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                flex: 2,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Going 1st',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Tooltip(
                  message: playerTurn == PlayerTurn.going1st
                      ? 'You play first'
                      : 'Opponent plays first',
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Switch(
                        value: !playerTurn.value,
                        thumbIcon: WidgetStateProperty.resolveWith((states) {
                          return Icon(
                            playerTurn == PlayerTurn.going1st
                                ? Icons.looks_one_rounded
                                : Icons.looks_two_rounded,
                            color: playerTurn == PlayerTurn.going1st
                                ? Colors.yellow[600]
                                : Colors.cyan,
                          );
                        }),
                        onChanged: (value) {
                          setState(() {
                            playerTurn = !value
                                ? PlayerTurn.going1st
                                : PlayerTurn.going2nd;
                          });
                        },
                        trackColor: WidgetStateColor.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                              : Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                        ),
                        thumbColor: WidgetStateColor.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest
                              : Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Going 2nd',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: TextField(
                    autocorrect: false,
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Opponent Username',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: DropdownButton<Rank>(
                    value: rank,
                    hint: const Text('Opponent Rank'),
                    onChanged: (value) {
                      setState(() {
                        rank = value;
                      });
                    },
                    items: Rank.values.reversed
                        .map(
                          (rank) => DropdownMenuItem<Rank>(
                            value: rank,
                            child: Text(rank.name.toTitleCase()),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^(-|)\d*'),
                      ),
                    ],
                    autocorrect: false,
                    controller: _mmrController,
                    decoration: const InputDecoration(
                      labelText: '+/- MMR',
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'),
                      ),
                    ],
                    autocorrect: false,
                    controller: _primeController,
                    decoration: const InputDecoration(
                      labelText: 'PRIME',
                    ),
                  ),
                ),
              ],
            ),
          ),
          FittedBox(
            child: Text(
              "Opponent's Paragon",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44, right: 44),
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.spaceAround,
              children: ParallelType.values
                  .where((parallel) => parallel != ParallelType.universal)
                  .map(
                    (parallel) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: SizedBox.square(
                        dimension: 80,
                        child: ParallelAvatar(
                          parallel: parallel,
                          isSelected: chosenParagon.parallel == parallel,
                          onSelection: (paragon) {
                            setState(() {
                              if (chosenParagon == paragon) {
                                chosenParagon = Paragon.unknown;
                              } else {
                                chosenParagon = paragon;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SegmentedButton<MatchResultOption>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: MatchResultOption.win,
                        label: Text(MatchResultOption.win.tooltip),
                        enabled: chosenParagon != Paragon.unknown,
                        icon: Icon(
                          MatchResultOption.win.icon,
                          color: MatchResultOption.win.color.withOpacity(
                            chosenParagon == Paragon.unknown ? 0.5 : 1,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: MatchResultOption.draw,
                        label: Text(MatchResultOption.draw.tooltip),
                        enabled: chosenParagon != Paragon.unknown,
                        icon: Icon(
                          MatchResultOption.draw.icon,
                          color: MatchResultOption.draw.color.withOpacity(
                            chosenParagon == Paragon.unknown ? 0.5 : 1,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: MatchResultOption.loss,
                        label: Text(MatchResultOption.loss.tooltip),
                        enabled: chosenParagon != Paragon.unknown,
                        icon: Icon(
                          MatchResultOption.loss.icon,
                          color: MatchResultOption.loss.color.withOpacity(
                            chosenParagon == Paragon.unknown ? 0.5 : 1,
                          ),
                        ),
                      ),
                    ],
                    selected: const {},
                    emptySelectionAllowed: true,
                    multiSelectionEnabled: false,
                    onSelectionChanged: (selection) async {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar(
                        reason: SnackBarClosedReason.hide,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        BasicSnack(
                          content: Text(
                            "Saving ${selection.first.name} vs ${chosenParagon.title.isEmpty ? chosenParagon.name.toTitleCase() : chosenParagon.title}",
                          ),
                        ),
                      );
                      await matchList.add(
                        MatchModel(
                          paragon: widget.chosenParagon,
                          opponentUsername: _usernameController.text,
                          opponentParagon: chosenParagon,
                          playerTurn: playerTurn,
                          matchTime: DateTime.now().toUtc(),
                          result: selection.first,
                          opponentRank: rank,
                          mmrDelta: int.tryParse(_mmrController.text) ?? 0,
                          primeEarned:
                              double.tryParse(_primeController.text) ?? 0,
                        ),
                      );
                      setState(() {
                        playerTurn = PlayerTurn.going1st;
                        chosenParagon = Paragon.unknown;
                        rank = null;
                        _usernameController.clear();
                        _mmrController.clear();
                        _primeController.clear();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
