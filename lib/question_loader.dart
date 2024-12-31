// question_loader.dart

import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'dart:math';

bool arePlayersCompatible(Map<String, dynamic> p1, Map<String, dynamic> p2) {
  // Basic placeholder: everyone is considered compatible
  // or insert orientation logic here if needed
  return true;
}

int findCompatiblePartner(int currentIndex, List<Map<String, dynamic>> allPlayers) {
  // Shuffle candidates, pick first that is compatible
  final candidates = List.generate(allPlayers.length, (i) => i)..remove(currentIndex);
  candidates.shuffle();
  for (int cIndex in candidates) {
    if (arePlayersCompatible(allPlayers[currentIndex], allPlayers[cIndex])) {
      return cIndex;
    }
  }
  return -1; // none found
}

class Prompt {
  final String category;       // "Truth", "Dare", "Wild", "DrinkIf", etc.
  final int level;            // 1..5, or 0 for DrinkIf
  final String promptText;
  final bool requiresPartner;
  final bool timed;
  final int timerSeconds;

  Prompt({
    required this.category,
    required this.level,
    required this.promptText,
    required this.requiresPartner,
    required this.timed,
    required this.timerSeconds,
  });
}

Future<List<Prompt>> loadPromptsFromCsv(String path) async {
  final rawCsv = await rootBundle.loadString(path);
  List<List<dynamic>> rows = const CsvToListConverter().convert(rawCsv, eol: '\n');
  List<Prompt> prompts = [];

  for (int i = 1; i < rows.length; i++) {
    final row = rows[i];
    // category,level,promptText,requiresPartner,timed,timerSeconds
    final cat = row[0].toString().trim();
    final lvl = int.tryParse(row[1].toString()) ?? 1;
    final txt = row[2].toString().trim();
    final reqP = row[3].toString().toLowerCase() == 'true';
    final tm = row[4].toString().toLowerCase() == 'true';
    final secs = int.tryParse(row[5].toString()) ?? 0;

    prompts.add(
      Prompt(
        category: cat,
        level: lvl,
        promptText: txt,
        requiresPartner: reqP,
        timed: tm,
        timerSeconds: secs,
      ),
    );
  }
  return prompts;
}

/// A manager to help find the right prompt
class PromptManager {
  final List<Prompt> allPrompts;
  final Random _rng = Random();

  PromptManager(this.allPrompts);

  /// Get a random prompt for a given category & level
  Prompt? getRandomPrompt(String category, int level, List<Map<String, dynamic>> players) {
    final relevant = allPrompts.where((p) =>
      p.category.toLowerCase() == category.toLowerCase() && p.level == level
    ).toList();
    if (relevant.isEmpty) return null;

    // We'll filter out any that require a partner if no partner is possible
    final filtered = <Prompt>[];
    for (final p in relevant) {
      if (!p.requiresPartner) {
        filtered.add(p);
      } else {
        // Check if there's at least one partner
        if (_checkAnyPartner(players)) {
          filtered.add(p);
        }
      }
    }
    if (filtered.isEmpty) return null;
    return filtered[_rng.nextInt(filtered.length)];
  }

  bool _checkAnyPartner(List<Map<String, dynamic>> players) {
    return players.length >= 2; // very simple check
  }

  /// For "DrinkIf" usage
  Prompt? getRandomDrinkIf() {
    final drinks = allPrompts.where((p) => p.category.toLowerCase() == 'drinkif').toList();
    if (drinks.isEmpty) return null;
    return drinks[_rng.nextInt(drinks.length)];
  }
}
