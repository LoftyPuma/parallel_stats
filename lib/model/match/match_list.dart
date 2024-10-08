import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:primea/main.dart';
import 'package:primea/model/deck/deck_model.dart';
import 'package:primea/model/match/match_model.dart';
import 'package:primea/model/match/match_result_option.dart';
import 'package:primea/model/match/match_results.dart';
import 'package:primea/model/season/season.dart';
import 'package:primea/tracker/match.dart';
import 'package:primea/util/analytics.dart';

class MatchList extends ChangeNotifier {
  final MatchResults matchResults;
  final GlobalKey<AnimatedListState> _listKey;
  final List<MatchModel> _matchList;

  static const int _limit = 100;
  static const Duration _sessionTolerance = Duration(hours: 3);

  int _totalMatches = 0;
  bool initialized = false;

  MatchList(
    GlobalKey<AnimatedListState> listKey,
    this.matchResults,
  )   : _listKey = listKey,
        _matchList = List.empty(growable: true);

  GlobalKey<AnimatedListState> get listKey => _listKey;

  int get limit => _limit;

  bool get isEmpty => _matchList.isEmpty;

  MatchModel get first => _matchList.first;

  MatchModel get last => _matchList.last;

  int get length => _matchList.length;

  int get total => _totalMatches;

  int get winStreak => max(
        _matchList.indexWhere(
          (element) => element.result != MatchResultOption.win,
        ),
        0,
      );

  int get sessionCount {
    if (_matchList.isEmpty) {
      return 0;
    }
    DateTime lastMatchTime = _matchList.first.matchTime;
    return _matchList.fold(1, (acc, match) {
      if (match.matchTime.isBefore(
        lastMatchTime.subtract(_sessionTolerance),
      )) {
        acc++;
      }
      lastMatchTime = match.matchTime;
      return acc;
    });
  }

  Iterable<MatchModel>? nextSession(int index) {
    if (_matchList.isEmpty) {
      return [];
    }

    DateTime lastMatchTime = _matchList.first.matchTime;
    int sessionStartIndex = 0;
    // Find the end of the most recent session
    int sessionEndIndex = _matchList.indexWhere(
      (match) {
        if (match.matchTime.isAfter(
          lastMatchTime.subtract(_sessionTolerance),
        )) {
          lastMatchTime = match.matchTime;
          return false;
        } else {
          return true;
        }
      },
    );

    // loop through the list to find the indexed session
    for (var i = 0; i < index; i++) {
      if (sessionEndIndex == _matchList.length) {
        // if we've reached the end of the list, there are no more sessions
        return null;
      }
      // Find the start of the next session
      sessionStartIndex = sessionEndIndex;
      lastMatchTime = _matchList[sessionStartIndex].matchTime;
      // Find the end of the next session
      sessionEndIndex = _matchList.indexWhere(
        (match) {
          if (match.matchTime.isAfter(
            lastMatchTime.subtract(_sessionTolerance),
          )) {
            // if the match is inside the session tolerance, we've found the end of the session
            lastMatchTime = match.matchTime;
            return false;
          } else {
            // if the match is outside the session tolerance, we've found the start of the next session
            lastMatchTime = match.matchTime;
            return true;
          }
        },
        sessionStartIndex,
      );
      if (sessionEndIndex == -1) {
        // if we've reached the end of the list, there are no more sessions
        sessionEndIndex = _matchList.length;
        break;
      }
    }
    if (sessionEndIndex == -1) {
      sessionEndIndex = _matchList.length;
    }
    // return the indexed session
    return _matchList.getRange(sessionStartIndex, sessionEndIndex);
  }

  operator [](int index) => _matchList[index];

  Future<void> init(Future<Season> season) async {
    try {
      final matches = await _fetchMatches(await season);
      _matchList.addAll(matches);
      _listKey.currentState?.insertAllItems(0, matches.length,
          duration: const Duration(milliseconds: 250));
      initialized = true;
      notifyListeners();
    } on Error catch (e) {
      Analytics.instance.trackEvent("initError", {
        "error": e.toString(),
        "class": "matchList",
        "stackTrace": e.stackTrace.toString(),
      });
    }
  }

  Future<Iterable<MatchModel>> _fetchMatches(
    Season season,
  ) async {
    Iterable<Future<MatchModel>> results = [];
    int from = 0;
    do {
      var matches = await supabase
          .from(MatchModel.gamesTableName)
          .select('*, decks(*)')
          .eq('season', season.id)
          .order("game_time")
          .range(from, from + _limit - 1)
          .count();

      _totalMatches = matches.count;
      final enrichedMatched = matches.data.map((game) async {
        if (game['decks'] != null) {
          game['deck'] = await DeckModel.fromJson(game['decks']).toDeck();
        }
        return MatchModel.fromJson(game);
      });
      results = results.followedBy(enrichedMatched);
      from += enrichedMatched.length;
    } while (_totalMatches > results.length);
    return Future.wait(results);
  }

  MatchModel? findMatch(String id) {
    try {
      return _matchList.singleWhere(
        (element) => element.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> add(MatchModel newMatch) async {
    final newMatchResponse = await supabase
        .from(MatchModel.gamesTableName)
        .insert(
          [
            newMatch.toJson(),
          ],
          defaultToNull: false,
        )
        .select()
        .limit(1)
        .single();
    if (newMatchResponse['deck_id'] == newMatch.deck?.id) {
      newMatchResponse['deck'] = newMatch.deck;
    }
    final newMatchModel = MatchModel.fromJson(newMatchResponse);
    _matchList.insert(0, newMatchModel);
    matchResults.recordMatch(newMatchModel);
    _totalMatches++;
    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 250),
    );
    notifyListeners();
  }

  Future<void> addAll(Iterable<MatchModel> newMatches) async {
    final List<dynamic> insertedMatches = await supabase
        .from(MatchModel.gamesTableName)
        .insert(
          newMatches.map((match) => match.toJson()).toList(),
          defaultToNull: false,
        )
        .select();

    final currentLength = _matchList.length;
    _matchList.addAll(insertedMatches.map(
      (match) => MatchModel.fromJson(match),
    ));
    _listKey.currentState?.insertAllItems(
      currentLength,
      insertedMatches.length,
      duration: const Duration(milliseconds: 250),
    );
    for (var match in insertedMatches) {
      matchResults.recordMatch(match);
    }
    _totalMatches += insertedMatches.length;
    notifyListeners();
  }

  Future<void> update(MatchModel match) async {
    final index = _matchList.indexWhere((element) => element.id == match.id);
    if (index != -1 && match.id != null) {
      await supabase
          .from(MatchModel.gamesTableName)
          .update(match.toJson())
          .eq("id", match.id!);

      matchResults.updateMatch(_matchList[index], match);

      // if the match time has changed, we need to remove and reinsert the match
      if (_matchList[index].matchTime != match.matchTime) {
        final removed = _matchList.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: Match(
              match: removed,
              onEdit: null,
              onDelete: null,
            ),
          ),
          duration: const Duration(milliseconds: 250),
        );

        final closestIndex = _matchList.indexWhere(
          (element) => element.matchTime.isBefore(match.matchTime),
        );
        _matchList.insert(closestIndex, removed);
        _listKey.currentState?.insertItem(
          closestIndex,
          duration: const Duration(milliseconds: 250),
        );
      } else {
        _matchList[index] = match;
      }

      notifyListeners();
    }
  }

  Future<MatchModel> remove(MatchModel toRemove) async {
    final index = _matchList.indexWhere((element) => element.id == toRemove.id);
    final removed = _matchList.removeAt(index);
    await supabase
        .from(MatchModel.gamesTableName)
        .delete()
        .eq("id", removed.id!)
        .select();
    _totalMatches--;
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: Match(
          match: removed,
          onEdit: null,
          onDelete: null,
        ),
      ),
      duration: const Duration(milliseconds: 250),
    );
    notifyListeners();
    return removed;
  }

  void clear() {
    _matchList.clear();
    _listKey.currentState?.removeAllItems(
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: Match(
          match: _matchList[0],
          onEdit: null,
          onDelete: null,
        ),
      ),
      duration: const Duration(),
    );
    _totalMatches = 0;
    initialized = false;
    notifyListeners();
  }
}
